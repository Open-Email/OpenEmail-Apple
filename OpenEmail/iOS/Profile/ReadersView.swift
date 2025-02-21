import SwiftUI
import Flow
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel

struct ReadersView: View {
    @AppStorage(UserDefaultsKeys.profileName) private var profileName: String?
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    private let isEditable: Bool
    @Binding private var readers: [EmailAddress]
    @Binding private var tickedReaders: [String]
    @Binding private var hasInvalidReader: Bool
    private var pendingText: Binding<String>?

    @State private var inputText = ""
    @State private var inputEditingPosition: Int = 0
    @State private var showAlreadyAddedAlert = false

    @State private var showSuggestions = false
    @State private var allContacts: [Contact] = []
    @State private var suggestions: [Contact] = []

    @FocusState private var isFocused: Bool

    // store which profiles have been shown to not show them again automatically
    @State private var profilesShown = Set<EmailAddress>()

    @State private var tokens: [ReaderToken] = []

    @Injected(\.contactsStore) private var contactsStore
    @Injected(\.client) private var client

    @State private var presentedProfileAddress: EmailAddress?
    @State private var presentedProfile: Profile?

    private var validReaders: [EmailAddress] {
        tokens
            .filter { $0.isValid == true && $0.convertedToToken }
            .compactMap { EmailAddress($0.value) }
    }

    private var pendingAdddress: String {
        let token = tokens.first { $0.convertedToToken == false }
        return token?.value ?? ""
    }

    init(
        isEditable: Bool,
        readers: Binding<[EmailAddress]>,
        tickedReaders: Binding<[String]>,
        hasInvalidReader: Binding<Bool>,
        pendingText: Binding<String>? = nil
    ) {
        self.isEditable = isEditable
        _readers = readers
        _tickedReaders = tickedReaders
        _hasInvalidReader = hasInvalidReader
        self.pendingText = pendingText
    }

    func validateToken(_ token: String) -> Bool {
        EmailAddress(token) != nil
    }

    var body: some View {
        // TODO: only display first 10 readers with option to expand to see all
        TokenTextField(
            tokens: $tokens,
            validateToken: validateToken,
            isEditable: isEditable,
            label: {
                ReadersLabelView()
            },
            onSelectToken: { token in
                guard let address = EmailAddress(token.value) else { return }
                presentedProfileAddress = address
                profilesShown.insert(address)
            },
            onTokenAdded: onTokenAdded
        )
        .task {
            updateTokensFromReaders()
        }
        .onChange(of: tokens) {
            readers = validReaders
            pendingText?.wrappedValue = pendingAdddress
        }
        .onChange(of: readers) {
            updateTokensFromReaders()
        }
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .focusable()
        .focused($isFocused)
        .onAppear {
            Task {
                allContacts = (try? await contactsStore.allContacts()) ?? []
                updateSuggestions()
            }
        }
        .popover(item: $presentedProfileAddress) { emailAddress in
            profilePopover(emailAddress: emailAddress)
        }
        .task {
            await updateAllContactsStates()
        }
    }

    private func updateTokensFromReaders() {
        let currentReaders = Set(tokens.map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isNotEmpty })
        let newReaders = Set(readers.map { $0.address.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isNotEmpty })

        let removedReaders = currentReaders.subtracting(newReaders)
        for removedReader in removedReaders {
            tokens.removeAll { $0.value == removedReader }
        }

        var newTokens = [ReaderToken]()

        for reader in readers {
            guard !tokens.contains(where: { $0.value == reader.address }) else {
                continue
            }

            // don't show reader if it is myself, except when I am the only reader or when composing a message
            let isMe = reader.address == registeredEmailAddress
            if !isMe || readers.count == 1 || isEditable {
                let token = ReaderToken(value: reader.address, isValid: true, isMe: isMe)
                newTokens.append(token)
            }
        }

        if newTokens.isNotEmpty {
            if tokens.last?.convertedToToken == false {
                tokens.removeLast()
            }
            tokens.append(contentsOf: newTokens)

            newTokens.forEach {
                onTokenAdded($0)
            }
        }
    }

    private func closeProfile() {
        presentedProfileAddress = nil
        presentedProfile = nil
    }

    private func onRemoveReader(_ token: ReaderToken) {
        tokens.removeAll(where: { $0.id == token.id })
    }

    private func onTokenAdded(_ token: ReaderToken) {
        Task {
            await checkMyContacts(for: token)
        }
    }

    private func updateSuggestions() {
        let searchString = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !searchString.isEmpty else {
            suggestions = []
            return
        }

        suggestions = allContacts.filter { contact in
            contact.address.localizedStandardContains(searchString) || (contact.cachedName ?? "").localizedStandardContains(searchString)
        }
    }

    private func updateAllContactsStates() async {
        for token in tokens {
            await checkMyContacts(for: token)
        }
    }

    private func checkMyContacts(for token: ReaderToken) async {
        guard let emailAddress = EmailAddress(token.value) else { return }

        let isMe = emailAddress.address == registeredEmailAddress
        let contactName: String?
        let isInMyContacts: Bool

        if isMe {
            contactName = "me"
            isInMyContacts = true
        } else {
            let contact = try? await contactsStore.contact(address: emailAddress.address)
            contactName = contact?.cachedName
            isInMyContacts = contact != nil
        }

        if !isMe && !isInMyContacts && !profilesShown.contains(emailAddress) && isEditable {
            presentedProfileAddress = emailAddress
        }

        tokens = tokens.map {
            if $0.id == token.id {
                var editableToken = $0
                editableToken.displayName = contactName
                editableToken.isInMyContacts = isInMyContacts
                editableToken.isMe = isMe
                return editableToken
            } else {
                return $0
            }
        }
    }

    private func profilePopover(emailAddress: EmailAddress) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProfileView(
                    emailAddress: emailAddress,
                    showActionButtons: false,
                    onProfileLoaded: { profile, _ in
                        presentedProfile = profile
                    })

                if
                    isEditable,
                    let token = tokens.first(where: { $0.value == emailAddress.address })
                {
                    HStack {
                        Button("Remove Reader", role: .destructive) {
                            onRemoveReader(token)
                            closeProfile()
                        }

                        if token.value != registeredEmailAddress, !token.isInMyContacts {
                            AsyncButton("Add Contact") {
                                let usecase = AddToContactsUseCase()
                                try? await usecase.add(emailAddress: emailAddress, cachedName: presentedProfile?[.name])
                                await checkMyContacts(for: token)
                                closeProfile()
                            }
                            .disabled(presentedProfile == nil)
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.themeBackground)
                }
            }
            .profilePopoverToolbar(closeProfile: closeProfile)
        }
    }
}

#Preview("1 reader") {
    VStack(alignment: .leading) {
        ReadersView(isEditable: false, readers: .constant([EmailAddress("mickey.mouse@disneymail.com")].compactMap { $0 }), tickedReaders: .constant([]), hasInvalidReader: .constant(false))
    }
    .padding()
}

#Preview("10 readers") {
    VStack(alignment: .leading) {
        ReadersView(
            isEditable: false,
            readers: .constant([
                EmailAddress("mickey@disneymail.com"),
                EmailAddress("min@magic.com"),
                EmailAddress("don@quack.com"),
                EmailAddress("daisy@flowerpowermail.com"),
                EmailAddress("goofy@laughtermail.com"),
                EmailAddress("pluto@starstruckmail.com"),
                EmailAddress("cinderella@fairytal.com"),
                EmailAddress("buzz@toinfinitymail.com"),
                EmailAddress("ariel@undertheseamail.com"),
                EmailAddress("simba@savannahmail.com"),
            ].compactMap { $0 }),
            tickedReaders: .constant([
                "mickey.mouse@disneymail.com",
                "minnie.mouse@magicmail.com"
            ].compactMap { $0 }),
            hasInvalidReader: .constant(false))
    }
    .padding()
}

#Preview("20 readers") {
    VStack(alignment: .leading) {
        ReadersView(
            isEditable: false,
            readers: .constant([
                EmailAddress("mickey.mouse@disneymail.com"),
                EmailAddress("minnie.mouse@magicmail.com"),
                EmailAddress("donald.duck@quackmail.com"),
                EmailAddress("daisy.duck@flowerpowermail.com"),
                EmailAddress("goofy.goof@laughtermail.com"),
                EmailAddress("pluto.pup@starstruckmail.com"),
                EmailAddress("cinderella.princess@fairytalemail.com"),
                EmailAddress("buzz.lightyear@toinfinitymail.com"),
                EmailAddress("ariel.mermaid@undertheseamail.com"),
                EmailAddress("simba.lionking@savannahmail.com"),
                EmailAddress("woody.cowboy@toystorymail.com"),
                EmailAddress("jessie.cowgirl@yeehawmail.com"),
                EmailAddress("aladdin.streetrat@agrabahmail.com"),
                EmailAddress("jasmine.princess@palacemail.com"),
                EmailAddress("pocahontas.naturelover@windmail.com"),
                EmailAddress("mulan.warrior@honoratemail.com"),
                EmailAddress("frozen.anna@snowqueenmail.com"),
                EmailAddress("elsa.icequeen@frozenmail.com"),
                EmailAddress("rapunzel.longhair@towermail.com"),
                EmailAddress("genie.freewisher@magiclampmail.com"),
            ].compactMap { $0 }),
            tickedReaders: .constant([
                "mickey.mouse@disneymail.com",
                "minnie.mouse@magicmail.com"
            ].compactMap { $0 }),
            hasInvalidReader: .constant(false))
    }
}

#Preview("editable") {
    @Previewable @State var readers: [EmailAddress] = []
    VStack(alignment: .leading) {
        Divider()
        ReadersView(isEditable: true, readers: $readers, tickedReaders: .constant([]), hasInvalidReader: .constant(false))
        Divider()
    }
    .padding()
}

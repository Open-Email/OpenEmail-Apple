import SwiftUI
import Flow
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel

struct ReadersView: View {
    @AppStorage(UserDefaultsKeys.profileName) private var profileName: String?
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    private static let zeroWidthSpace = "\u{200B}"
    private let isEditable: Bool
    @Binding private var readers: [Profile]
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

    @Injected(\.contactsStore) private var contactsStore
    @Injected(\.client) private var client

    @State private var presentedProfile: Profile?

    init(
        isEditable: Bool,
        readers: Binding<[Profile]>,
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
        HFlow(itemSpacing: 4, rowSpacing: 2) {
            ForEach(Array(readers.enumerated()), id: \.offset) { index, reader in
                if reader.address.address != registeredEmailAddress || readers.count == 1 || isEditable {
                    ProfileTagView(
                        profile: reader,
                        isSelected: presentedProfile?.address.address == reader.address.address,
                        isTicked: tickedReaders.contains(reader.address.address),
                        onRemoveReader: {
                            readers.remove(at: index)
                        },
                        automaticallyShowProfileIfNotInContacts: isEditable,
                        canRemoveReader: isEditable,
                        showsActionButtons: !isEditable,
                        onShowProfile: { profile in
                            presentedProfile = profile
                        }
                    ).id(reader.address.address)
                }
            }
            
            if isEditable {
                /*
                 The TextField's first character is an invisible space which helps with a more natural
                 editing experience. E.g. when deleting the current input with backspace and the invisible space
                 is deleted, we can load the previous tag's text into the TextField and continue editing there.
                 */
                
                TextField("", text: $inputText)
                    .font(.body)
                    .padding(.vertical, .Spacing.xSmall)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 20, maxWidth: .infinity)
                    .onChange(of: inputText) {
                        if !readers.isEmpty && inputText.isEmpty {
                            let last = readers.removeLast()
                            inputText = ReadersView.zeroWidthSpace + last.address.address
                        }
                        
                        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        hasInvalidReader = !trimmed.isEmpty && !EmailAddress.isValid(trimmed)
                        
                        updateSuggestions()
                        
                        showSuggestions = inputText
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).count >= 1 && !suggestions.isEmpty
                    }
                    .onSubmit {
                        addCurrentInput()
                    }

//                    .onReceive(NotificationCenter.default.publisher(for: NSTextView.didChangeSelectionNotification)) {
//                        guard let textView = $0.object as? NSTextView else { return }
//                        DispatchQueue.main.async {
//                            guard isInputFocused else { return }
//                            
//                            // delay fixing cursor position because isInputFocused is only set after this notification
//                            fixInitialCursorPositionIfNeeded(textView: textView)
//                            
//                            fixSelection(textView: textView)
//                            
//                            inputEditingPosition = textView.selectedRange().location
//                        }
//                    }
                    .popover(
                        isPresented: $showSuggestions,
                    ) {
                        ContactSuggestionsView(suggestions: suggestions) { suggestion in
                            inputText = suggestion.address
                            addCurrentInput()
                            showSuggestions = false
                        }.presentationCompactAdaptation(.popover)
                    }
            }
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
        .popover(item: $presentedProfile) { profile in
            NavigationStack {
                VStack(spacing: 0) {
                    ProfileView(profile: profile)
                    
                    if isEditable {
                        HStack {
                            Button("Remove Reader", role: .destructive) {
                                let index = readers.firstIndex(of: profile)!
                                readers.remove(at: index)
                                closeProfile()
                            }
                            
                            if profile.address.address != registeredEmailAddress, !allContacts
                                .contains(
                                    where: { $0.address == profile.address.address }) {
                                AsyncButton("Add Contact") {
                                    let usecase = AddToContactsUseCase()
                                    try? await usecase.add(emailAddress: profile.address, cachedName: presentedProfile?[.name])
                                    closeProfile()
                                }
                                .disabled(presentedProfile == nil)
                            }
                        }
                        .buttonStyle(.bordered)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.themeViewBackground)
                    }
                }
                .profilePopoverToolbar(closeProfile: closeProfile)
            }
        }
    }

    private func closeProfile() {
        presentedProfile = nil
    }

    private func addCurrentInput() {
        showSuggestions = false
        //TODO
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
}

#Preview("1 reader") {
    VStack(alignment: .leading) {
        ReadersView(isEditable: false, readers: .constant([
            Profile(
                address: EmailAddress("mickey.mouse@disneymail.com")!,
                profileData: [:]
            )].compactMap { $0 }), tickedReaders: .constant([]), hasInvalidReader: .constant(false))
    }
    .padding()
}

#Preview("10 readers") {
    VStack(alignment: .leading) {
        ReadersView(
            isEditable: false,
            readers: .constant([
                Profile(
                    address: EmailAddress("mickey@disneymail.com")!,
                    profileData: [:]
                ),
                Profile(
                    address: EmailAddress("min@magic.com")!,
                    profileData: [:]
                ),
                Profile(
                    address: EmailAddress("don@quack.com")!,
                    profileData: [:]
                ),
                Profile(
                    address: EmailAddress("daisy@flowerpowermail.com")!,
                    profileData: [:]
                )
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
                Profile(
                    address: EmailAddress("mickey@disneymail.com")!,
                    profileData: [:]
                    ),
                    Profile(
                        address: EmailAddress("min@magic.com")!,
                        profileData: [:]
                    ),
                    Profile(
                        address: EmailAddress("don@quack.com")!,
                        profileData: [:]
                    ),
                    Profile(
                        address: EmailAddress("daisy@flowerpowermail.com")!,
                        profileData: [:]
                    )
            ].compactMap { $0 }),
            tickedReaders: .constant([
                "mickey.mouse@disneymail.com",
                "minnie.mouse@magicmail.com"
            ].compactMap { $0 }),
            hasInvalidReader: .constant(false))
    }
}

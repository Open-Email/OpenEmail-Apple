import SwiftUI
import Flow
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel
import Logging

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
    @State private var noProfileFoundAlertShown: Bool = false
    @State private var addingContactProgress: Bool = false

    @State private var showSuggestions = false
    @State private var allContacts: [Contact] = []
    @State private var suggestions: [Contact] = []

    @FocusState private var isFocused: Bool

    @Injected(\.contactsStore) private var contactsStore
    @Injected(\.client) private var client

    @State private var presentedProfile: Profile?
    @State private var newContact: Profile?

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
                HStack(spacing: .Spacing.xxxSmall) {
                    ReadersLabelView()
                    TextField("", text: $inputText)
                        .font(.body)
                        .padding(.vertical, .Spacing.xSmall)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 20, maxWidth: .infinity)
                        .onChange(of: inputText) {
                            if let last = inputText.last,
                                last == " " || last == "," {
                                inputText = inputText
                                    .trimmingCharacters(
                                        in: CharacterSet(charactersIn: " ,")
                                    )
                                addCurrentInput()
                            }
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
        }
        .sheet(isPresented: Binding(
            get: {
                Binding($newContact) != nil
            },
            set: { newValue in
                if !newValue {
                    newContact = nil
                    addingContactProgress = false
                }
            })
        ) {
            VStack(alignment: .leading) {
                HStack {
                    Text("This person should be added to your contact list first")
                        .font(.footnote)
                    Spacer()
                    if addingContactProgress {
                        ProgressView()
                    } else {
                        AsyncButton("Add to contacts") {
                            if let localUser = LocalUser.current, let profile = newContact {
                                addingContactProgress = true
                                do {
                                    try await client
                                        .storeContact(
                                            localUser: localUser,
                                            address: profile.address
                                        )
                                    let contact = Contact(
                                        id: localUser.connectionLinkFor(remoteAddress: profile.address.address),
                                        addedOn: Date(),
                                        address: profile.address.address,
                                        receiveBroadcasts: true,
                                        cachedName: profile[.name],
                                        cachedProfileImageURL: nil
                                    )
                                    try await contactsStore.storeContact(contact)
                                } catch {
                                    Log.error("could not add contact: \(error)")
                                }
                                inputText = ReadersView.zeroWidthSpace
                                readers.append(profile)
                                newContact = nil
                                addingContactProgress = false
                            }
                        }
                    }
                }
                .padding(.top, .Spacing.default)
                .padding(.horizontal, .Spacing.default)
                
                
                ProfileView(profile: newContact!)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        newContact = nil
                    }
                    
                }.padding(.Spacing.default)
            }
        }
        .alert("Reader already added", isPresented: $showAlreadyAddedAlert) {}
        .alert("No profile registered with address: \(inputText.trimmingCharacters(in: .whitespacesAndNewlines))", isPresented: $noProfileFoundAlertShown) {}
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
            }
        }
    }

    private func closeProfile() {
        presentedProfile = nil
    }

    private func addCurrentInput() {
        showSuggestions = false
        
        let address = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let emailAddress = EmailAddress(address) {
            if readers
                .contains(where: { reader in reader.address == emailAddress }) {
                showAlreadyAddedAlert = true
            } else {
                Task {
                    let savedContact = try? await contactsStore.contact(
                        address: emailAddress.address
                    )
                    
                    if let profile = try? await client.fetchProfile(
                        address: emailAddress,
                        force: false
                    ) {
                        if savedContact == nil {
                            newContact = profile
                        } else {
                            inputText = ReadersView.zeroWidthSpace
                            readers.append(profile)
                        }
                    } else {
                        noProfileFoundAlertShown = true
                    }
                }
            }
        } else {
            inputText = ReadersView.zeroWidthSpace
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

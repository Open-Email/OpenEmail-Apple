import SwiftUI
import OpenEmailCore
import OpenEmailPersistence

struct ProfileTagView: View {
    @Environment(\.isEnabled) var isEnabled: Bool
    @AppStorage(UserDefaultsKeys.profileName) var profileName: String?

    struct Configuration {
        var automaticallyShowProfileIfNotInContacts: Bool
        var canRemoveReader: Bool
        var showsActionButtons: Bool

        /// If not `nil` this is called when the profile should be shown. The receiver is responsible for correctly
        /// showing the profile.
        /// If `nil`, the profile is shown as a popover over the profile tag view.
        var onShowProfile: ((String) -> Void)?
    }

    @State private var isInMyContacts: Bool = true
    @State private var isInOtherContacts: Bool?
    @State private var isTicked: Bool = false
    @State private var contactName: String?
    @State private var hasLoadedProfile: Bool = false
    @State private var showContactPopover = false

    @Injected(\.client) private var client
    @Injected(\.contactsStore) private var contactsStore: ContactStoring

    @Binding var emailAddress: String?
    var isSelected: Bool
    var configuration: Configuration
    var onRemoveReader: (() -> Void)?

    private var isMyself: Bool {
        emailAddress == LocalUser.current?.address.address
    }

    private var indicateThatNotInOthersContacts: Bool {
        isInOtherContacts == false
    }

    init(
        emailAddress: Binding<String?>,
        isSelected: Bool,
        isTicked: Bool = false,
        configuration: Configuration,
        onRemoveReader: (() -> Void)? = nil
    ) {
        _emailAddress = emailAddress
        self.isSelected = isSelected
        self.isTicked = isTicked
        self.configuration = configuration
        self.onRemoveReader = onRemoveReader
    }

    private var foregroundColor: Color {
        if isSelected {
            return .white
        } else {
            return .primary
        }
    }

    var body: some View {
        HStack(spacing: .Spacing.xxxSmall) {
            if isInMyContacts {
                Image(.readerInContacts)
            } else {
                Image(.readerNotInContacts)
            }

            if isMyself {
                Text("me")
            } else {
                Text(contactName?.truncated(to: 30) ?? emailAddress ?? "–")
            }

            if isTicked {
                Image(systemName: "checkmark")
                    .controlSize(.mini)
                    .bold()
            }
        }
        .lineLimit(1)
        .padding(.vertical, .Spacing.xxxSmall)
        .padding(.horizontal, .Spacing.xSmall)
        .foregroundStyle(foregroundColor)
        .background(Capsule().fill(.themeBadgeBackground))
        .help(isInMyContacts ? "Reader is in my contacts" : "Reader is not in my contacts")
        .onTapGesture {
            guard isEnabled else { return }
            showProfile()
        }
        .popover(isPresented: $showContactPopover) {
            profilePopover()
        }
        .onAppear {
            updateContactsState()
        }
        .onChange(of: emailAddress) {
            updateContactsState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateContacts)) { _ in
            updateContactsState()
        }
    }

    private func updateContactsState() {
        Task {
            await checkMyContacts()
            await checkOtherContacts()
        }
    }

    private func checkMyContacts() async {
        guard let emailAddress else { return }

        if isMyself {
            contactName = profileName
            return
        }

        let contact = try? await contactsStore.contact(address: emailAddress)

        contactName = contact?.cachedName

        isInMyContacts = contact != nil
        if !isInMyContacts && configuration.automaticallyShowProfileIfNotInContacts {
            showProfile()
        }
    }

    private func showProfile() {
        guard let emailAddress else { return }
        if let onShowProfile = configuration.onShowProfile {
            onShowProfile(emailAddress)
        } else {
            showContactPopover = true
        }
    }

    private func checkOtherContacts() async {
        guard
            let localUser = LocalUser.current,
            let emailAddress = EmailAddress(emailAddress)
        else {
            return
        }

        isInOtherContacts = try? await client.isAddressInContacts(localUser: localUser, address: emailAddress)
    }

    @ViewBuilder
    private func profilePopover() -> some View {
        if let emailAddress = EmailAddress(emailAddress) {
            VStack {
                let viewModel = ProfileViewModel(emailAddress: emailAddress) { profile, _ in
                    hasLoadedProfile = profile != nil
                }

                ProfileView(
                    viewModel: viewModel,
                    showActionButtons: configuration.showsActionButtons,
                    verticalLayout: false,
                    profileImageSize: 200
                )
                .frame(idealWidth: 500, minHeight: 250)

                if configuration.canRemoveReader && (!isInMyContacts || indicateThatNotInOthersContacts) {
                    HStack {
                        Spacer()
                        Button("Remove Reader") {
                            onRemoveReader?()
                            showContactPopover = false
                        }

                        if !isMyself && !isInMyContacts {
                            AsyncButton("Add Contact") {
                                let usecase = AddToContactsUseCase()
                                try? await usecase.add(emailAddress: emailAddress, cachedName: nil)
                                updateContactsState()
                                showContactPopover = false
                            }
                            .disabled(!hasLoadedProfile)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(.themeViewBackground)
        }
    }
}

#if DEBUG

#Preview {
    VStack {
        ProfileTagView(emailAddress: .constant("mickey@mouse.com"), isSelected: false, isTicked: false, configuration: .fake, onRemoveReader: nil)

        ProfileTagView(emailAddress: .constant("mickey@mouse.com"), isSelected: true, isTicked: true, configuration: .fake, onRemoveReader: nil)
    }
    .padding()
    .background(.themeViewBackground)
}

private extension ProfileTagView.Configuration {
    static let fake = ProfileTagView.Configuration(
        automaticallyShowProfileIfNotInContacts: false,
        canRemoveReader: false,
        showsActionButtons: true
    )
}

#endif

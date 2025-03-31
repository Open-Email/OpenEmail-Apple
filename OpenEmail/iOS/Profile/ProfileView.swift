import SwiftUI
import OpenEmailCore
import Logging

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) var registeredEmailAddress: String?

    private let showActionButtons: Bool
    private let isContactRequest: Bool
    @State private var showRemoveContactConfirmationAlert = false
    @State private var showsComposeView = false

    init(
        emailAddress: EmailAddress,
        showActionButtons: Bool = true,
        isContactRequest: Bool = false,
        onProfileLoaded: ((Profile?, Error?) -> Void)? = nil
    ) {
        self.showActionButtons = showActionButtons
        self.isContactRequest = isContactRequest
        viewModel = ProfileViewModel(emailAddress: emailAddress, onProfileLoaded: onProfileLoaded)
    }

    var body: some View {
        if viewModel.isLoadingProfile {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else {
            if !viewModel.isLoadingProfile && viewModel.profile != nil {
                let canEditReceiveBroadcasts = !viewModel.isSelf && viewModel.isInContacts
                ProfileAttributesView(
                    profile: $viewModel.profile,
                    receiveBroadcasts: canEditReceiveBroadcasts && viewModel.receiveBroadcasts != nil ? Binding(
                        get: {
                            viewModel.receiveBroadcasts ?? true
                        },
                        set: { newValue in
                            Task {
                                await viewModel.updateReceiveBroadcasts(newValue)
                            }
                        }) : nil,
                    isEditable: false,
                    hidesEmptyFields: true,
                    profileImageStyle: .fullWidthHeader(height: 450),
                    actionButtonRow: actionButtons
                )
                .sheet(isPresented: $showsComposeView) {
                    if let registeredEmailAddress {
                        ComposeMessageView(action: .newMessage(id: UUID(), authorAddress: registeredEmailAddress, readerAddress: viewModel.emailAddress.address))
                    }
                }
            } else {
                errorView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private func actionButtons() -> some View {
        if !viewModel.isSelf, showActionButtons {
            HStack {
                ProfileActionButton(title: "Refresh", icon: .refresh) {
                    viewModel.refreshProfile()
                }

                if viewModel.isInContacts {
                    ProfileActionButton(title: "Fetch", icon: .attachmentDownload) {
                        Task {
                            await viewModel.fetchMessages()
                        }
                    }

                    ProfileActionButton(title: "Message", icon: .compose) {
                        showsComposeView = true
                    }

                    ProfileActionButton(title: "Delete", icon: .trash, role: .destructive) {
                        showRemoveContactConfirmationAlert = true
                    }
                    .alert("Are you sure you want to remove this contact?", isPresented: $showRemoveContactConfirmationAlert) {
                        Button("Cancel", role: .cancel) {}
                        AsyncButton("Remove", role: .destructive) {
                            await removeUser()
                        }
                    } message: {
                        Text("This action cannot be undone.")
                    }
                } else {
                    ProfileActionButton(title: "Add ", icon: .addContact) {
                        Task {
                            await addToContacts()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var errorView: some View {
        VStack {
            HStack(spacing: .Spacing.xxxSmall) {
                WarningIcon()
                Text(viewModel.errorText)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Retry") {
                    viewModel.refreshProfile()
                }
                .buttonStyle(.borderedProminent)

                if viewModel.isInContacts && !viewModel.isSelf {
                    AsyncButton("Remove User", role: .destructive) {
                        await removeUser()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .controlSize(.small)
        }
    }

    private func removeUser() async {
        do {
            try await viewModel.removeFromContacts()
        } catch {
            // TODO: show error
            Log.error("Could not remove contact:", context: error)
        }
    }

    private func addToContacts() async {
        do {
            try await viewModel.addToContacts()
        } catch {
            // TODO: show error
            Log.error("Could not add contact:", context: error)
        }
    }
}

#if DEBUG

#Preview("full profile") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake()
    InjectedValues[\.client] = client

    return ProfileView(
        emailAddress: .init("mickey@mouse.com")!,
        showActionButtons: true,
        isContactRequest: false,
        onProfileLoaded: nil
    )
}

#Preview("away") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake(awayWarning: "Gone for vacation 🌴")
    InjectedValues[\.client] = client

    return ProfileView(
        emailAddress: .init("mickey@mouse.com")!,
        showActionButtons: true,
        isContactRequest: false,
        onProfileLoaded: nil
    )
}

#Preview("no name") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake(name: nil)
    InjectedValues[\.client] = client

    return ProfileView(
        emailAddress: .init("mickey@mouse.com")!,
        showActionButtons: true,
        isContactRequest: false,
        onProfileLoaded: nil
    )
}

#Preview("no action buttons") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake()
    InjectedValues[\.client] = client

    let contactsStore = ContactStoreMock()
    InjectedValues[\.contactsStore] = contactsStore

    return ProfileView(
        emailAddress: .init("mickey@mouse.com")!,
        showActionButtons: false,
        isContactRequest: false,
        onProfileLoaded: nil
    )
}

#endif

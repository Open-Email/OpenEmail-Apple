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
        profile: Profile,
        showActionButtons: Bool = true,
        isContactRequest: Bool = false,
    ) {
        self.showActionButtons = showActionButtons
        self.isContactRequest = isContactRequest
        viewModel = ProfileViewModel(profile: profile)
    }

    var body: some View {
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
            hidesEmptyFields: true,
            profileImageStyle: .fullWidthHeader(height: 450),
            actionButtonRow: actionButtons
        )
        .sheet(isPresented: $showsComposeView) {
            if let registeredEmailAddress {
                ComposeMessageView(action: .newMessage(id: UUID(), authorAddress: registeredEmailAddress, readerAddress: viewModel.profile.address.address))
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
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
        showActionButtons: true,
        isContactRequest: false,
    )
}

#Preview("away") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake(awayWarning: "Gone for vacation 🌴")
    InjectedValues[\.client] = client

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
        showActionButtons: true,
        isContactRequest: false,
    )
}

#Preview("no name") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake(name: nil)
    InjectedValues[\.client] = client

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
        showActionButtons: true,
        isContactRequest: false,
    )
}

#Preview("no action buttons") {
    let client = EmailClientMock()
    client.stubFetchedProfile = .makeFake()
    InjectedValues[\.client] = client

    let contactsStore = ContactStoreMock()
    InjectedValues[\.contactsStore] = contactsStore

    return ProfileView(
        profile: .init(address: .init("mickey@mouse.com")!, profileData: [:]),
        showActionButtons: false,
        isContactRequest: false,
    )
}

#endif

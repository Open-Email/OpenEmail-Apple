import SwiftUI
import OpenEmailCore
import Logging

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    @Injected(\.client) private var client
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
        self.viewModel = ProfileViewModel(profile: profile)
        self.showActionButtons = showActionButtons
        self.isContactRequest = isContactRequest
    }

    var body: some View {
        let canEditReceiveBroadcasts = !viewModel.isSelf && viewModel.isInContacts
        
        ProfileAttributesView(
            profile: Binding<Profile>(
                get: { viewModel.profile },
                set: { viewModel.profile = $0 }
            ),
            showBroadcasts: canEditReceiveBroadcasts,
            receiveBroadcasts: Binding(
                get: {
                    viewModel.receiveBroadcasts
                },
                set: { newValue in
                    Task {
                        await viewModel.updateReceiveBroadcasts(newValue)
                    }
                }),
            profileImageStyle: .fullWidthHeader(height: 450),
            actionButtonRow: actionButtons
        )
        .sheet(isPresented: $showsComposeView) {
            if let registeredEmailAddress {
                ComposeMessageView(
                    action:
                            .newMessage(
                                id: UUID(),
                                authorAddress: registeredEmailAddress,
                                readerAddress: viewModel.profile.address.address
                            )
                )
            }
        }
    }

    @ViewBuilder
    private func actionButtons() -> some View {
        if !viewModel.isSelf && showActionButtons {
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

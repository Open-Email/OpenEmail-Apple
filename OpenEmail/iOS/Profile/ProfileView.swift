import SwiftUI
import OpenEmailCore
import Logging

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
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
        VStack(spacing: .zero) {
            ProfileImageView(
                emailAddress: viewModel.profile.address.address,
                shape: .rectangle,
                size: .huge
            ).frame(maxWidth: .infinity, maxHeight: 400)
            
            ProfileAttributesView(
                profile: Binding<Profile>(
                    get: { viewModel.profile },
                    set: { viewModel.profile = $0 }
                ),
                showBroadcasts: !viewModel.isSelf && viewModel.isInContacts,
                receiveBroadcasts: Binding(
                    get: {
                        viewModel.receiveBroadcasts
                    },
                    set: { newValue in
                        Task {
                            await viewModel.updateReceiveBroadcasts(newValue)
                        }
                    }),
                profileImageStyle: .none,
            )
        }.ignoresSafeArea(.all, edges: .top)
       
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.isInContacts {
                   
                    Button {
                        showRemoveContactConfirmationAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    
                    Button {
                        showsComposeView = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    
                } else {
                    if !viewModel.isSelf {
                        Button {
                            Task {
                                await addToContacts()
                            }
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
            }
        }
        .alert("Are you sure you want to remove this contact?", isPresented: $showRemoveContactConfirmationAlert) {
            Button("Cancel", role: .cancel) {}
            AsyncButton("Remove", role: .destructive) {
                await removeUser()
            }
        } message: {
            Text("This action cannot be undone.")
        }
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

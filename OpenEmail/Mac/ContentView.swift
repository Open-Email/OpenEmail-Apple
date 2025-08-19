import SwiftUI
import Combine
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence
import Logging

struct ContentView: View {
    @Injected(\.syncService) private var syncService
    @Environment(NavigationState.self) private var navigationState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @AppStorage(UserDefaultsKeys.profileName) private var profileName: String?
    
    private let contactRequestsController = ContactRequestsController()
    
    @State private var fetchButtonRotation = 0.0
    @State private var searchText: String = ""
    @State private var showAddContactView: Bool = false
    @State private var showsAddContactError = false
    @State private var addContactError: Error?
    @State private var contactsListViewModel: ContactsListViewModel = ContactsListViewModel()
    @State private var messageThreadViewModel: MessageThreadViewModel = MessageThreadViewModel(messageThread: nil)
    
    private let contactsOrNotificationsUpdatedPublisher = Publishers.Merge(
        NotificationCenter.default.publisher(for: .didUpdateContacts),
        NotificationCenter.default.publisher(for: .didUpdateNotifications)
    ).eraseToAnyPublisher()
    
    var body: some View {
        NavigationSplitView {
            MessagesListView(searchText: $searchText)
        }  detail: {
            VStack {
                if navigationState.selectedMessageThreads.isEmpty {
                    Image(.logo)
                        .saturation(0.0)
                        .opacity(0.25)
                        .frame(height: 32, alignment: .leading)
                    
                } else {
                    messagesDetailView
                }
            }
            .frame(minWidth: 300, idealWidth: 650)
        }
        .toolbar {
            ToolbarItemGroup {
                
                AsyncButton {
                    await triggerSync()
                } label: {
                    SyncProgressView()
                }
                .disabled(syncService.isSyncing)
                
                Button {
                    guard let registeredEmailAddress else { return }
                    
                    openWindow(id: WindowIDs.compose, value: ComposeAction.newMessage(id: UUID(), authorAddress: registeredEmailAddress, readerAddress: nil))
                    
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                
                Button {
                    showAddContactView = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                Button {
                    openWindow(id: WindowIDs.contacts)
                } label: {
                    Image(systemName: "person.3")
                }
                Spacer()
                Button {
                    openWindow(id: WindowIDs.profileEditor)
                } label: {
                    HStack(spacing: .Spacing.small) {
                        ProfileImageView(
                            emailAddress: registeredEmailAddress,
                            size: .tiny
                        )
                        if let name = profileName {
                            Text(name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .font(.caption2)
                        }
                    }
                }
            }
            
            
        }
        .sheet(isPresented: $showAddContactView) {
            ContactsAddressInputView { address in
                contactsListViewModel.onAddressSearch(address: address)
                showAddContactView = false
            } onCancel: {
                contactsListViewModel.onAddressSearchDismissed()
                showAddContactView = false
            }
        }.alert("Could not add contact", isPresented: $showsAddContactError, actions: {
            Button("OK") {
                showAddContactView = true
            }
        }, message: {
            if let addContactError {
                Text("Underlying error: \(String(describing: addContactError))")
            }
        })
        .alert("Contact already exists", isPresented: $contactsListViewModel.showsContactExistsError, actions: {})
        .sheet(isPresented: Binding<Bool>(
            get: {
                contactsListViewModel.contactToAdd != nil
            },
            set: { _ in }
        )) {
            ProfilePreviewSheetView(
                profile: contactsListViewModel.contactToAdd!,
                onCancelled: {
                    contactsListViewModel.onAddressSearchDismissed()
                },
                onAddContactClicked: { address in
                    Task {
                        do {
                            try await contactsListViewModel.addContact()
                        } catch {
                            Log.error("Error while adding contact: \(error)")
                            addContactError = error
                            showsAddContactError = true
                        }
                    }
                }
            )
        }
        .searchable(
            text: $searchText,
            placement: SearchFieldPlacement.sidebar
        )
        .onChange(of: navigationState.selectedMessageThreads) {
            if navigationState.selectedMessageThreads.count == 1 {
                messageThreadViewModel.messageThread = navigationState.selectedMessageThreads.first
            } else {
                messageThreadViewModel.messageThread = nil
            }
        }
        .onChange(of: searchText) {
            contactsListViewModel.searchText = searchText
        }
    }
    
    
    @ViewBuilder
    private var messagesDetailView: some View {
        if navigationState.selectedMessageThreads.count > 1 {
            MultipleMessagesView()
        } else {
            MessageThreadView(
                messageViewModel: $messageThreadViewModel,
            ).id(navigationState.selectedMessageThreads.first)
        }
    }
    
    private func triggerSync() async {
        await syncService.synchronize()
    }
}

struct ProfilePreviewSheetView: View {
    let profile: Profile
    let onCancelled: () -> Void
    let onAddContactClicked: (Profile) -> Void
    
    init(
        profile: Profile,
        onCancelled: @escaping () -> Void,
        onAddContactClicked: @escaping (Profile) -> Void
    ) {
        self.profile = profile
        self.onAddContactClicked = onAddContactClicked
        self.onCancelled = onCancelled
    }
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 0) {
            ProfileView(
                profile: profile,
            )
            
            HStack {
                Spacer()
                
                Button("Cancel", role: .cancel) {
                    onCancelled()
                }
                
                Button("Add", role: .cancel) {
                    onAddContactClicked(profile)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(profile.address == LocalUser.current?.address)
            }.padding(.Spacing.default)
        }
    }
}

struct ContactDetailView: View {
    @Injected(\.client) private var client
    @State private var viewModel: ProfileViewModel?
    
    private let selectedContactListItem: ContactListItem?
    
    init(selectedContact: ContactListItem?) {
        self.selectedContactListItem = selectedContact
    }
    
    var body: some View {
        VStack {
            if viewModel != nil && !viewModel!.isSelf && !viewModel!.isInContacts {
                HStack {
                    AsyncButton {
                        do {
                            try await viewModel?.addToContacts()
                        } catch {
                            Log.error("Could not add to contacts keys:", context: error)
                        }
                    } label: {
                        Text("Add to contacts")
                        
                    }.buttonStyle(.borderedProminent)
                    Spacer()
                    
                }.padding(.top, .Spacing.xSmall)
                    .padding(
                        .horizontal,
                        .Spacing.default
                    )
            }
            if let profile = viewModel?.profile {
                ProfileView(
                    profile: profile,
                )
                .background(.themeViewBackground)
                .id(profile.address.address)
            }
        }
        .task {
            if let contact = selectedContactListItem, let address = EmailAddress(
                contact.email
            ) {
                if let profile = try? await client.fetchProfile(address: address, force: false) {
                    viewModel = ProfileViewModel(profile: profile)
                }
                
            } else {
                viewModel = nil
            }
        }
    }
}

struct SyncProgressView: View {
    @State private var rotation: CGFloat = 0
    @Injected(\.syncService) private var syncService
    
    var body: some View {
        Group {
            if syncService.isSyncing {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .rotationEffect(.degrees(rotation))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
        }
        .onChange(of: syncService.isSyncing) {
            rotation = syncService.isSyncing ? 360 : 0
        }
    }
}

#Preview {
    ContentView()
        .environment(NavigationState())
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle("")
}

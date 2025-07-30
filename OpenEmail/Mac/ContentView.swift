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
    
    private let contactRequestsController = ContactRequestsController()
    
    @State private var showDeleteMessageConfirmationAlert = false
    @State private var showDeleteContactConfirmationAlert = false
    @State private var fetchButtonRotation = 0.0
    @State private var searchText: String = ""
    @State private var showAddContactView = false
    @State private var showsAddContactError = false
    @State private var addContactError: Error?
    @State private var contactsListViewModel: ContactsListViewModel = ContactsListViewModel()
    @State private var sidebarViewModel: ScopesSidebarViewModel = ScopesSidebarViewModel()
    @State private var messageViewModel: MessageViewModel = MessageViewModel(
        messageID: nil
    )
    
    private let contactsOrNotificationsUpdatedPublisher = Publishers.Merge(
        NotificationCenter.default.publisher(for: .didUpdateContacts),
        NotificationCenter.default.publisher(for: .didUpdateNotifications)
    ).eraseToAnyPublisher()
    
    var body: some View {
        NavigationSplitView {
            Group {
                if navigationState.selectedScope == .contacts {
                    ContactsListView(contactsListViewModel: $contactsListViewModel)
                } else {
                    MessagesListView(searchText: $searchText)
                }
            }.toolbar {
                ToolbarItem(placement: ToolbarItemPlacement.primaryAction) {
                    AsyncButton {
                        await triggerSync()
                    } label: {
                        SyncProgressView()
                    }
                    .disabled(syncService.isSyncing)
                }
                
            }
        }  detail: {
            VStack {
                if navigationState.selectedContact == nil && navigationState.selectedMessageIDs.isEmpty {
                    Image(.logo)
                        //.aspectRatio(contentMode: .fit)
                        .saturation(0.0)
                        .opacity(0.25)
                        .frame(height: 32, alignment: .leading)
                    
                } else {
                    if navigationState.selectedScope == .contacts {
                        ContactDetailView(
                            selectedContact: navigationState.selectedContact
                        ).id(navigationState.selectedContact?.id)
                    } else {
                        messagesDetailView
                    }
                }
            }
            .frame(minWidth: 300, idealWidth: 650)
            .toolbar {
                ToolbarItem(placement: ToolbarItemPlacement.primaryAction) {
                    Button {
                        guard let registeredEmailAddress else { return }
                        
                        if messageViewModel.message?.isDraft == true {
                            openWindow(
                                id: WindowIDs.compose,
                                value: ComposeAction.editDraft(messageId: messageViewModel.messageID!)
                            )
                        } else {
                            openWindow(id: WindowIDs.compose, value: ComposeAction.newMessage(id: UUID(), authorAddress: registeredEmailAddress, readerAddress: nil))
                        }
                        
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
                ToolbarItem {
                    Button {
                        showAddContactView = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
                ToolbarItem {
                    AsyncButton {
                        switch navigationState.selectedScope {
                            case .trash:
                                showDeleteMessageConfirmationAlert = true
                                
                            case .contacts:
                                if let _ = navigationState.selectedContact {
                                    showDeleteContactConfirmationAlert = true
                                }
                            default:
                                do {
                                    try await messageViewModel.markAsDeleted(true)
                                    navigationState.clearSelection()
                                } catch {
                                    Log.error("Could not mark message as deleted: \(error)")
                                }
                        }
                    } label: {
                        Image(systemName: "trash")
                    }.disabled(
                        navigationState.selectedMessageIDs.isEmpty &&
                        navigationState.selectedContact == nil
                    ).help((messageViewModel.message?.isDraft ?? false) ? "Delete draft" : "Delete message")
                }
                ToolbarItem {
                    Button {
                        guard let registeredEmailAddress else { return }
                        if let message = messageViewModel.message {
                            openWindow(
                                id: WindowIDs.compose,
                                value: ComposeAction.reply(
                                    id: UUID(),
                                    authorAddress: registeredEmailAddress,
                                    messageId: message.id,
                                    quotedText: message.body
                                )
                            )
                        }
                    } label: {
                        Image(systemName: "arrowshape.turn.up.left")
                    }.disabled(
                        messageViewModel.message == nil || messageViewModel.message!.isDraft
                    )
                }
                ToolbarItem {
                    Button {
                        guard let registeredEmailAddress else { return }
                        if let message = messageViewModel.message {
                            openWindow(
                                id: WindowIDs.compose,
                                value: ComposeAction.replyAll(
                                    id: UUID(),
                                    authorAddress: registeredEmailAddress,
                                    messageId: message.id,
                                    quotedText: message.body
                                )
                            )
                        }
                        
                    } label: {
                        Image(systemName: "arrowshape.turn.up.left.2")
                    }.disabled(
                        messageViewModel.message == nil || messageViewModel.message!.isDraft
                    )
                }
                ToolbarItem {
                    Button {
                        guard let registeredEmailAddress else { return }
                        if let message = messageViewModel.message {
                            openWindow(
                                id: WindowIDs.compose,
                                value: ComposeAction.forward(
                                    id: UUID(),
                                    authorAddress: registeredEmailAddress,
                                    messageId: message.id
                                )
                            )
                        }
                    } label: {
                        Image(systemName: "arrowshape.turn.up.right")
                    }.disabled(
                        messageViewModel.message == nil || messageViewModel.message!.isDraft
                    )
                }
                //Spacer()
            }
        }
        .searchable(
            text: $searchText,
        )
        .alert(
            navigationState.selectedContact?.isContactRequest == true ?
            "Are you sure you want to dismiss this contact request?" :
                "Are you sure you want to delete this contact?",
            isPresented: $showDeleteContactConfirmationAlert
        ) {
            Button("Cancel", role: .cancel) {}
            AsyncButton(navigationState.selectedContact?.isContactRequest == true ? "Dismiss" : "Delete", role: .destructive) {
                if let contact = navigationState.selectedContact {
                    if let email = EmailAddress(
                        contact.email
                    ) {
                        do {
                            try await DeleteContactUseCase().deleteContact(emailAddress: email)
                            navigationState.clearSelection()
                        } catch {
                            Log.error("Could not delete contact \(email): \(error)")
                        }
                    }
                }
            }
        }
        .alert("Are you sure you want to delete this message?", isPresented: $showDeleteMessageConfirmationAlert) {
            Button("Cancel", role: .cancel) {}
            AsyncButton("Delete", role: .destructive) {
                await permanentlyDeleteSentMessage()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .onChange(of: navigationState.selectedMessageIDs) {
            if navigationState.selectedMessageIDs.count == 1 {
                messageViewModel.messageID = navigationState.selectedMessageIDs.first
            } else {
                messageViewModel.messageID = nil
            }
            
        }
        .onChange(of: searchText) {
            contactsListViewModel.searchText = searchText
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
    }
    
    private func permanentlyDeleteSentMessage() async {
        do {
            try await messageViewModel.permanentlyDeleteMessage()
            navigationState.clearSelection()
        } catch {
            Log.error("Could not delete message: \(error)")
        }
    }
    
    @ViewBuilder
    private var messagesDetailView: some View {
        if navigationState.selectedMessageIDs.count > 1 {
            MultipleMessagesView()
        } else {
            if let _ = messageViewModel.message {
                MessageView(
                    messageViewModel: $messageViewModel,
                ).id(navigationState.selectedMessageIDs.first)
            }
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

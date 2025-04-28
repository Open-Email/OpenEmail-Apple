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
    
    var amountLabel: String? {
        switch sidebarViewModel.selectedScope {
        case .broadcasts:
            let broadcastsCount = sidebarViewModel.allCounts[.broadcasts] ?? 0
            let unreadProadcastsCount = sidebarViewModel.unreadCounts[.broadcasts] ?? 0
            return "\(broadcastsCount) broadcasts" + (unreadProadcastsCount > 0 ? " \(unreadProadcastsCount) unread" : "")
        case .inbox:
            let inboxCount = sidebarViewModel.allCounts[.inbox] ?? 0
            let unreadInboxCount = sidebarViewModel.unreadCounts[.inbox] ?? 0
            return "\(inboxCount) messages" + (unreadInboxCount > 0 ? " \(unreadInboxCount) unread" : "")
        case .outbox:
            let sentCount = sidebarViewModel.allCounts[.outbox] ?? 0
            return "\(sentCount) messages"
        case .drafts:
            let draftsCount = sidebarViewModel.allCounts[.drafts] ?? 0
            return "\(draftsCount) drafts"
        case .trash:
            let deletedCount = sidebarViewModel.allCounts[.trash] ?? 0
            return "\(deletedCount) deleted messages"
        case .contacts:
            let contactsCount = sidebarViewModel.allCounts[.contacts] ?? 0
            let requestsCount = sidebarViewModel.unreadCounts[.contacts] ?? 0
            return "\(contactsCount) contacts" + (requestsCount > 0 ? " \(requestsCount) requests" : "")
        }
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(scopesSidebarViewModel: $sidebarViewModel)
        } content: {
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
                ToolbarItem {
                    VStack(alignment: .leading) {
                        Text(navigationState.selectedScope.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        if let amountLabel = amountLabel {
                            Text(amountLabel)
                                .font(.subheadline)
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                                .truncationMode(.tail)
                        }
                    }
                    
                }
                
            }
        } detail: {
            VStack {
                if navigationState.selectedContact == nil && navigationState.selectedMessageIDs.isEmpty {
                    Text("No selection")
                        .bold()
                        .foregroundStyle(.tertiary)
                } else {
                    if navigationState.selectedScope == .contacts {
                        ContactDetailView(
                            selectedContact: navigationState.selectedContact
                        ).id(navigationState.selectedContact?.id)
                    } else {
                        messagesDetailView
                    }
                }
            }.toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    HStack {
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
                        
                        Button {
                            showAddContactView = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                        Divider()
                        AsyncButton {
                            switch navigationState.selectedScope {
                            case .trash:
                                showDeleteMessageConfirmationAlert = true
                            case .outbox, .drafts:
                                do {
                                    try await messageViewModel.markAsDeleted(true)
                                    navigationState.clearSelection()
                                } catch {
                                    Log.error("Could not mark message as deleted: \(error)")
                                }
                            case .contacts:
                                if let _ = navigationState.selectedContact {
                                    showDeleteContactConfirmationAlert = true
                                }
                            default:
                                Log.error("Non-deletable item selected")
                            }
                        } label: {
                            Image(systemName: "trash")
                        }.disabled(
                            (navigationState.selectedScope != .trash &&
                             navigationState.selectedScope != .outbox &&
                             navigationState.selectedScope != .drafts &&
                             navigationState.selectedScope != .contacts
                            ) ||
                            (
                                navigationState.selectedMessageIDs.isEmpty &&
                                navigationState.selectedContact == nil
                            )
                        )
                        //TODO adjust help according to selected element. Could be contact as well
                        .help((messageViewModel.message?.isDraft ?? false) ? "Delete draft" : "Delete message")
                    }
                }
            }
        }
        .searchable(text: $searchText)
        .alert(
            navigationState.selectedContact?.isContactRequest == true ?
            "Are you sure you want to dismiss this contact request?" :
                "Are you sure you want to delete this contact?",
            isPresented: $showDeleteContactConfirmationAlert
        ) {
            Button("Cancel", role: .cancel) {}
            AsyncButton(navigationState.selectedContact?.isContactRequest == true ? "Dismiss" : "Delete", role: .destructive) {
                if let contact = navigationState.selectedContact {
                    if (contact.isContactRequest) {
                        //TODO dismiss notification
                    } else {
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
    @Environment(\.dismiss) private var dismiss
    @State var profileViewModel: ProfileViewModel
    let profile: Profile
    let onAddContactClicked: ((Profile) -> Void)
    
    init(
        profile: Profile,
        onAddContactClicked: @escaping ((Profile) -> Void)
    ) {
        self.profile = profile
        self.onAddContactClicked = onAddContactClicked
        profileViewModel = ProfileViewModel(
            profile: profile,
        )
    }
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 0) {
            ProfileView(
                profile: profileViewModel.profile,
                showActionButtons: false,
                profileImageSize: 240
            )
            .padding(.top, -.Spacing.xSmall)
            
            HStack {
                Spacer()
                
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                
                Button("Add", role: .cancel) {
                    onAddContactClicked(profile)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(profileViewModel.profile.address == LocalUser.current?.address)
            }
            .padding(.horizontal, .Spacing.default)
            .padding(.bottom, .Spacing.default)
        }
        .background(.themeViewBackground)
    }
}

struct ContactDetailView: View {
    @Injected(\.client) private var client
    @State private var profile: Profile?
    private let selectedContactListItem: ContactListItem?
    
    init(selectedContact: ContactListItem?) {
        self.selectedContactListItem = selectedContact
    }
    
    var body: some View {
        VStack {
            if let profile = profile {
                ProfileView(
                    profile: profile,
                    isContactRequest: selectedContactListItem?.isContactRequest ?? false
                )
                .frame(minWidth: 600)
                .id(profile.address.address)
            }
        }.task {
            if let contact = selectedContactListItem, let address = EmailAddress(
                contact.email
            ) {
                profile = try? await client.fetchProfile(address: address, force: false)
            } else {
                profile = nil
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

private extension Date {
    var formattedNextSyncDate: String {
        let minutes = Int(timeIntervalSinceNow.asMinutes)
        if minutes >= 60 {
            let hours = Int(timeIntervalSinceNow.asHours)
            return "\(hours) hours"
        } else {
            return "\(minutes) min"
        }
    }
}

#Preview {
    ContentView()
        .environment(NavigationState())
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle("")
}

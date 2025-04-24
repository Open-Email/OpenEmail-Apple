import SwiftUI
import Combine
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence

struct ContentView: View {
    @Environment(NavigationState.self) private var navigationState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    private let contactRequestsController = ContactRequestsController()
    @Injected(\.syncService) private var syncService
    
    @State private var fetchButtonRotation = 0.0
    @State private var searchText: String = ""

    private let contactsOrNotificationsUpdatedPublisher = Publishers.Merge(
        NotificationCenter.default.publisher(for: .didUpdateContacts),
        NotificationCenter.default.publisher(for: .didUpdateNotifications)
    ).eraseToAnyPublisher()

    var body: some View {
        NavigationView {
            SidebarView()
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200)
            Group {
                if navigationState.selectedScope == .contacts {
                    ContactsListView(searchText: $searchText)
                } else {
                    MessagesListView(searchText: $searchText)
                }
            }
            .frame(minWidth: 250)
            Group {
                if navigationState.selectedScope == .contacts {
                    ContactDetailView(
                        selectedContact: navigationState.selectedContact
                    )
                } else {
                    messagesDetailView
                }
            }
            .frame(minWidth: 300)
        }.toolbar {
            detailsToolbarContent()
        }.searchable(text: $searchText)
            
    }

    @ToolbarContentBuilder
    private func detailsToolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: {
                NSApp.keyWindow?
                    .firstResponder?
                    .tryToPerform(
                        #selector(NSSplitViewController.toggleSidebar(_:)),
                        with: nil
                    )
            }) {
                Image(systemName: "sidebar.left")
            }
        }
        ToolbarItem {
            AsyncButton {
                await triggerSync()
            } label: {
                SyncProgressView()
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                guard let registeredEmailAddress else { return }
                openWindow(id: WindowIDs.compose, value: ComposeAction.newMessage(id: UUID(), authorAddress: registeredEmailAddress, readerAddress: nil))
            } label: {
                HStack {
                    Image(.compose)
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    Text("Create Message")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var messagesDetailView: some View {
        if navigationState.selectedMessageIDs.count > 1 {
            MultipleMessagesView()
        } else {
            MessageView(
                messageID: navigationState.selectedMessageIDs.first,
            )
        }
    }

    private func triggerSync() async {
        await syncService.synchronize()
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
            } else {
                Text("No selection")
                    .bold()
                    .foregroundStyle(.tertiary)
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

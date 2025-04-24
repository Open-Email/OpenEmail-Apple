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

    @State private var selectedMessageProfileAddress: EmailAddress?
    @State private var selectedProfileViewModel: ProfileViewModel?

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
                    contactsDetailView
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
                selectedProfileViewModel: selectedProfileViewModel,
                selectedMessageProfileAddress: $selectedMessageProfileAddress
            )
        }
    }

    @ViewBuilder
    private var contactsDetailView: some View {
        if let selectedContactListItem = navigationState.selectedContact,
           let email = EmailAddress(selectedContactListItem.email) {
            ProfileView(
                address: email,
                isContactRequest: selectedContactListItem.isContactRequest
            )
            .frame(minWidth: 600)
            .id(selectedContactListItem.email)
        } else {
            Text("No selection")
                .bold()
                .foregroundStyle(.tertiary)
        }
    }

    private func triggerSync() async {
        await syncService.synchronize()
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

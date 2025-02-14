import SwiftUI
import Combine
import OpenEmailCore

struct ContentView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    private let contactRequestsController = ContactRequestsController()
    @Injected(\.syncService) private var syncService
    
    @State private var hasContactRequests = false

    private let contactsOrNotificationsUpdatedPublisher = Publishers.Merge(
        NotificationCenter.default.publisher(for: .didUpdateContacts),
        NotificationCenter.default.publisher(for: .didUpdateNotifications)
    ).eraseToAnyPublisher()

    var body: some View {
        TabView {
            MessagesTabView()
                .tabItem {
                    Image(.messagesTab)
                    Text("Messages")
                }

            ContactsTabView()
                .tabItem {
                    Image(.scopeContacts)
                    Text("Contacts")
                }

            Text(registeredEmailAddress ?? "not logged in")
                .tabItem {
                    Image(.profileTab)
                    Text("Profile")
                }

            SettingsView()
                .tabItem {
                    Image(.settings)
                    Text("Settings")
                }
        }
        .onReceive(contactsOrNotificationsUpdatedPublisher) { _ in
            updateContactRequests()
        }
        .onAppear {
            updateContactRequests()
            Task {
                await syncService.synchronize()
            }
        }
        .onChange(of: registeredEmailAddress) {
            Task {
                await syncService.synchronize()
            }
        }
    }

    private func updateContactRequests() {
        Task {
            hasContactRequests = await contactRequestsController.hasContactRequests
        }
    }
}

#Preview {
    ContentView()
}

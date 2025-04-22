import Foundation
import Observation
import Combine
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel

struct ScopeSidebarItem: Identifiable, Hashable {
    var id: String { scope.rawValue }
    let scope: SidebarScope
    let unreadCount: Int
}

@Observable
class ScopesSidebarViewModel {
    
    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore
    
    init() {
        NotificationCenter.default.publisher(for: .didUpdateNotifications).sink { notifications in
            Task {
                await self.reloadItems()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didUpdateMessages).sink { _ in
            Task {
                await self.reloadItems()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didUpdateContacts).sink { _ in
            Task {
                await self.reloadItems()
            }
        }.store(in: &subscriptions)
        
        UserDefaults.standard.publisher(for: \.registeredEmailAddress).sink { _ in
            Task {
                await self.reloadItems()
            }
        }.store(in: &subscriptions)
        
    }

    var unreadCounts: [SidebarScope: Int] = [:]
    var selectedScope: SidebarScope = .inbox
    private var subscriptions = Set<AnyCancellable>()

    private(set) var items: [ScopeSidebarItem] = []

    private let contactRequestsController = ContactRequestsController()

    private let triggerReloadSubject = PassthroughSubject<Void, Never>()
   

    @MainActor
    private func reloadItems() async {
        await updateUnreadCounts()

        items = SidebarScope.allCases.compactMap {
            #if os(iOS)
            // Contacts is a separate tab on iOS
            if $0 == .contacts { return nil }
            #endif

            return ScopeSidebarItem(
                scope: $0,
                unreadCount: unreadCounts[$0] ?? 0
            )
        }
    }

    private func updateUnreadCounts() async {
        unreadCounts = [:]
        
        guard let localUser = LocalUser.current else {
            return
        }

        guard let newUnreadCounts = await fetchUnreadCounts(localUser: localUser) else { return }
        unreadCounts = newUnreadCounts
    }

    private func fetchUnreadCounts(localUser: LocalUser) async -> [SidebarScope: Int]? {
        guard let allUnreadMessages = try? await messagesStore.allUnreadMessages() else {
            return nil
        }

        return [
            .broadcasts: allUnreadMessages.filteredBy(scope: .broadcasts, localUser: localUser).count,
            .inbox: allUnreadMessages.filteredBy(scope: .inbox, localUser: localUser).count,
            .contacts: await contactRequestsController.contactRequests.count
        ]
    }
}

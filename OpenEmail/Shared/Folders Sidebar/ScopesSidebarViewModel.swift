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
    var shouldShowNewMessageIndicator: Bool

    var subtitle: String? {
        if scope == .contacts && unreadCount > 0 {
            // This should be cleaned up by using a string catalog with pluralization
            if unreadCount == 1 {
                return "\(unreadCount) request"
            } else {
                return "\(unreadCount) requests"
            }
        }
        return nil
    }
}

@MainActor
@Observable
class ScopesSidebarViewModel {
    private var lastSeenUnreadCounts: [SidebarScope: Int] = [:]
    private var currentUnreadCounts: [SidebarScope: Int] = [:]
    private(set) var contactRequestsCount = 0

    var selectedScope: SidebarScope = .inbox {
        didSet {
            // on scope change set last seen count to current so the badge disappears
            lastSeenUnreadCounts[selectedScope] = currentUnreadCounts[selectedScope]
        }
    }

    private(set) var items: [ScopeSidebarItem] = []

    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore

    private let contactRequestsController = ContactRequestsController()

    private let triggerReloadSubject = PassthroughSubject<Void, Never>()
    private var subscriptions = Set<AnyCancellable>()

    func reloadItems(isInitialUpdate: Bool) async {
        await updateCounts(isInitialUpdate: isInitialUpdate)

        items = SidebarScope.allCases.compactMap {
            #if os(iOS)
            // Contacts is a separate tab on iOS
            if $0 == .contacts { return nil }
            #endif

            return ScopeSidebarItem(
                scope: $0,
                unreadCount: unreadCount(for: $0),
                shouldShowNewMessageIndicator: shouldShowNewMessageIndicator(for: $0)
            )
        }
    }

    private func updateCounts(isInitialUpdate: Bool) async {
        await updateUnreadCounts(isInitialUpdate: isInitialUpdate)
        await updateContactRequestsCount()
    }

    private func unreadCount(for scope: SidebarScope) -> Int {
        if scope == .contacts {
            return contactRequestsCount
        }

        return currentUnreadCounts[scope] ?? 0
    }

    private func shouldShowNewMessageIndicator(for scope: SidebarScope) -> Bool {
        if scope == .contacts {
            return contactRequestsCount > 0
        }

        guard
            let lastSeenUnreadCount = lastSeenUnreadCounts[scope],
            let currentUnreadCount = currentUnreadCounts[scope]
        else {
            return false
        }

        return currentUnreadCount > lastSeenUnreadCount
    }

    func updateUnreadCounts(isInitialUpdate: Bool) async {
        guard
            let localUser = LocalUser.current
        else {
            // clear counts if there is no user (e.g. after logout)
            lastSeenUnreadCounts = [:]
            currentUnreadCounts = [:]
            return
        }

        guard let unreadCounts = await fetchUnreadCounts(localUser: localUser) else { return }
        if isInitialUpdate {
            lastSeenUnreadCounts = unreadCounts
        } else {
            if let currentScopeCount = unreadCounts[selectedScope] {
                lastSeenUnreadCounts[selectedScope] = currentScopeCount
            }
        }

        currentUnreadCounts = unreadCounts
    }

    private func fetchUnreadCounts(localUser: LocalUser) async -> [SidebarScope: Int]? {
        guard let allUnreadMessages = try? await messagesStore.allUnreadMessages() else {
            return nil
        }

        return [
            .broadcasts: allUnreadMessages.filteredBy(scope: .broadcasts, localUser: localUser).count,
            .inbox: allUnreadMessages.filteredBy(scope: .inbox, localUser: localUser).count
        ]
    }

    private func updateContactRequestsCount() async {
        contactRequestsCount = await contactRequestsController.contactRequests.count
    }
}

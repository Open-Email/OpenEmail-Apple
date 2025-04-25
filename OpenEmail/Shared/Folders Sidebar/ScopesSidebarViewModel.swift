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
    @ObservationIgnored
    @Injected(\.contactsStore) private var contactStore
    
    init() {
        NotificationCenter.default.publisher(for: .didUpdateNotifications).sink { notifications in
            Task {
                await self.reloadItems()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didUpdateMessages).sink { _ in
            Task {
                await self.refreshMessages()
                await self.reloadItems()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didUpdateContacts).sink { _ in
            Task {
                await self.refreshContacts()
                await self.reloadItems()
            }
        }.store(in: &subscriptions)
        
        UserDefaults.standard.publisher(for: \.registeredEmailAddress).sink { _ in
            Task {
                await self.reloadItems()
            }
        }.store(in: &subscriptions)
        
        Task {
            await withTaskGroup { group in
                group.addTask {
                    await self.refreshMessages()
                }
                
                group.addTask {
                    await self.refreshContacts()
                }
                
                await group.waitForAll()
            }
        }
    }
    
    var allCounts: [SidebarScope: Int] = [:]
    var unreadCounts: [SidebarScope: Int] = [:]
    var selectedScope: SidebarScope = .inbox
    private var subscriptions = Set<AnyCancellable>()
    
    private(set) var items: [ScopeSidebarItem] = []
    
    private let contactRequestsController = ContactRequestsController()
    
    private let triggerReloadSubject = PassthroughSubject<Void, Never>()
    
    private func refreshMessages() async {
        let registeredEmailAddress: String = UserDefaults.standard.registeredEmailAddress ?? ""
        if let newMessages = try? await messagesStore.allMessages(searchText: "") {
            await withTaskGroup { group in
                group.addTask {
                    await MainActor.run {
                        self.allCounts[.broadcasts] = newMessages
                            .filter {
                                message in message.isBroadcast && message.author != registeredEmailAddress
                            }.count
                    }
                }
                
                group.addTask {
                    await MainActor.run {
                        self.allCounts[.outbox] = newMessages
                            .filter { message in
                                message.author == registeredEmailAddress
                            }.count
                    }
                }
                
                group.addTask {
                    await MainActor.run {
                        self.allCounts[.inbox] = newMessages
                            .filter {
                                message in !message.isBroadcast && message.author != registeredEmailAddress
                            }.count
                    }
                }
                
                group.addTask {
                    await MainActor.run {
                        self.allCounts[.drafts] = newMessages
                            .filter {
                                message in message.isDraft
                            }.count
                    }
                }
                
                group.addTask {
                    await MainActor.run {
                        self.allCounts[.trash] = newMessages
                            .filter {
                                message in message.isDeleted
                            }.count
                    }
                }
            }
        }
    }
    
    @MainActor
    private func refreshContacts() async {
        if let newContacts = try? await contactStore.allContacts() {
            self.allCounts[.contacts] = newContacts.count
        }
    }
    
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

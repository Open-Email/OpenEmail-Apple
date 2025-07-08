import Foundation
import Observation
import Combine
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel
import SwiftUI

struct ScopeSidebarItem: Identifiable, Hashable, Equatable {
    var id: String { scope.rawValue }
    let scope: SidebarScope
}

@Observable
class ScopesSidebarViewModel {
    
    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore
    @ObservationIgnored
    @Injected(\.pendingMessageStore) private var pendingMessageStore
    @ObservationIgnored
    @Injected(\.contactsStore) private var contactStore
    
    
    var allCounts: [SidebarScope: Int] = [:]
    var unreadCounts: [SidebarScope: Int] = [:]
    var selectedScope: SidebarScope = .inbox
    private var subscriptions = Set<AnyCancellable>()
    
    var items: [ScopeSidebarItem] {
        SidebarScope.allCases.compactMap {
#if os(iOS)
            // Contacts is a separate tab on iOS
            if $0 == .contacts { return nil }
#endif
            return ScopeSidebarItem(
                scope: $0,
            )
        }
    }
    
    private let contactRequestsController = ContactRequestsController()
    
    private let triggerReloadSubject = PassthroughSubject<Void, Never>()
    
    init() {
        NotificationCenter.default.publisher(for: .didUpdateNotifications).sink { notifications in
            Task {
                await self.refreshMessages()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didUpdateMessages).sink { _ in
            Task {
                await self.refreshMessages()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didUpdatePendingMessages).sink { _ in
            Task {
                await self.refreshPendingMessages()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didUpdateContacts).sink { _ in
            Task {
                await self.refreshContacts()
            }
        }.store(in: &subscriptions)
        
        UserDefaults.standard.publisher(for: \.registeredEmailAddress).sink { _ in
            Task {
                await withTaskGroup { group in
                    group.addTask {
                        await self.refreshMessages()
                    }
                    
                    group.addTask {
                        await self.refreshPendingMessages()
                    }
                    
                    group.addTask {
                        await self.refreshContacts()
                    }
                    
                    await group.waitForAll()
                }
            }
        }.store(in: &subscriptions)
        
        Task {
            await withTaskGroup { group in
                group.addTask {
                    await self.refreshMessages()
                }
#if os(MacOS)
                group.addTask {
                    await self.refreshContacts()
                }
#endif
                await group.waitForAll()
            }
        }
    }
    
    @MainActor
    private func refreshPendingMessages() async {
        if let pendingMessages = try? await pendingMessageStore.allPendingMessages(
            searchText: ""
        ) {
            await MainActor.run {
                self.unreadCounts[.outbox] = pendingMessages.count
            }
        }
    }
    
    @MainActor
    private func refreshMessages() async {
        guard let localUser = LocalUser.current else {
            return
        }
        if let newMessages = try? await messagesStore.allMessages(searchText: "") {
            await withTaskGroup { group in
                group.addTask {
                    let unreads: Int = (try? await self.messagesStore
                        .allUnreadMessages())?.filteredBy(scope: .broadcasts, localUser: localUser).count ?? 0
                    
                    await MainActor.run {
                        self.unreadCounts[.broadcasts] = unreads
                        self.allCounts[.broadcasts] = newMessages
                            .filteredBy(
                                scope: .broadcasts,
                                localUser: localUser
                            ).count
                    }
                }
                
                group.addTask {
                    await MainActor.run {
                        self.allCounts[.outbox] = newMessages
                            .filteredBy(
                                scope: .outbox,
                                localUser: localUser
                            ).count
                    }
                }
                
                group.addTask {
                    let unreads: Int = (try? await self.messagesStore
                        .allUnreadMessages())?.filteredBy(scope: .inbox, localUser: localUser).count ?? 0
                    await MainActor.run {
                        self.unreadCounts[.inbox] = unreads
                        self.allCounts[.inbox] = newMessages
                            .filteredBy(
                                scope: .inbox,
                                localUser: localUser
                            ).count
                    }
                }
                
                group.addTask {
                    await MainActor.run {
                        self.allCounts[.drafts] = newMessages.filteredBy(
                            scope: .drafts,
                            localUser: localUser
                        ).count
                    }
                }
                
                group.addTask {
                    await MainActor.run {
                        self.allCounts[.trash] = newMessages.filteredBy(
                            scope: .trash,
                            localUser: localUser
                        ).count
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
        self.unreadCounts[.contacts] =  await contactRequestsController.contactRequests.count
    }
}

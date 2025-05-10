import Foundation
import Observation
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence
import Logging
import Combine

@Observable
class MessagesListViewModel {
    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore
    @ObservationIgnored
    @Injected(\.archivedMessagesStore) private var archivedMessagesStore
    
    let messageDeletion: MessageDeletionUsecase = MessageDeletionUsecase()
    var scope: SidebarScope = .inbox {
        didSet {
            Task {
                await self.reloadMessagesFromStore()
            }
        }
    }

    var searchText: String = "" {
        didSet {
            Task {
                await self.reloadMessagesFromStore()
            }
        }
    }
    private var allMessages: [Message] = []
    private var allArchivedMessages: [Message] = []
    private var subscriptions = Set<AnyCancellable>()
    var messages: [Message] = []
    
    
    init() {
        NotificationCenter.default.publisher(for: .didUpdateMessages).sink { _ in
            Task {
                await self.reloadMessagesFromStore()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didUpdateArchivedMessages).sink { _ in
            Task {
                await self.reloadMessagesFromStore()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didSynchronizeMessages).sink { _ in
            Task {
                await self.reloadMessagesFromStore()
            }
        }.store(in: &subscriptions)
    }
    
    func deleteMessages(messageIDs: Set<String>) {
        Task {
            switch scope {
            case .outbox:
                //TODO show confirmation dialog
                try? await messageDeletion.recallMessages(messagesIDs: messageIDs)
            case .inbox, .broadcasts:
                await messageDeletion.putToTrash(messageIDs: messageIDs)
            case .trash:
                //TODO show confirmation dialog
                await messageDeletion.deleteFromTrash(messageIDs: messageIDs)
            default:
                break
            }
        }
    }

    @MainActor
    func reloadMessagesFromStore() async {
        do {
            allMessages = try await messagesStore.allMessages(searchText: searchText)
            allArchivedMessages = try await archivedMessagesStore.allArchivedMessages(searchText: searchText)
            
            if let localUser = LocalUser.current {
                switch scope {
                case .trash:
                    let filtered = allArchivedMessages
                        .filter { trashMessage in !trashMessage.isDeleted }
                    messages = filtered
                default:
                    messages = allMessages.filteredBy(scope: scope, localUser: localUser)
                }
            } else {
                messages = []
            }
        } catch {
            Log.error("Could not get messages from store:", context: error)
        }
    }

    func markAsRead(messageIDs: Set<String>) {
        setReadState(messageIDs: messageIDs, isRead: true)
    }

    func markAsUnread(messageIDs: Set<String>) {
        setReadState(messageIDs: messageIDs, isRead: false)
    }
    
    private func setReadState(messageIDs: Set<String>, isRead: Bool) {
        Task {
            do {
                guard let localUser = LocalUser.current else { return }

                var updatedMessages = [Message]()

                for messageID in messageIDs {
                    if let index = allMessages.firstIndex(where: { $0.id == messageID && $0.isRead != isRead }) {
                        var message = allMessages[index]
                        
                        // setting read state on messages the user sent doesn't make sense
                        guard message.author != localUser.address.address else { continue }

                        message.isRead = isRead
                        updatedMessages.append(message)

                        allMessages[index] = message
                    }
                }

                try await messagesStore.storeMessages(updatedMessages)
            } catch {
                Log.error("Could not mark message as read: \(error)")
            }
        }
    }
}

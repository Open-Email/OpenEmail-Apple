import Foundation
import Observation
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence
import Logging

@Observable
class MessagesListViewModel {
    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore

    private var allMessages: [Message] = []

    var messages: [Message] = []

    @MainActor
    func reloadMessagesFromStore(searchText: String, scope: SidebarScope?) async {
        do {
            allMessages = try await messagesStore.allMessages(searchText: searchText)

            if let scope, let localUser = LocalUser.current {
                messages = allMessages.filteredBy(scope: scope, localUser: localUser)
            } else {
                messages = allMessages
            }
        } catch {
            // TODO: show error message?
            Log.error("Could not get messages from store:", context: error)
        }
    }

    func markAsRead(messageIDs: Set<String>) {
        setReadState(messageIDs: messageIDs, isRead: true)
    }

    func markAsUnread(messageIDs: Set<String>) {
        setReadState(messageIDs: messageIDs, isRead: false)
    }
    
    func markAsDeleted(messageIDs: Set<String>, isDeleted: Bool) {
        Task {
            do {
                var updatedMessages = [Message]()
                
                allMessages.filter { messageIDs.contains($0.id) }.forEach {
                    var message = $0
                    message.deletedAt = isDeleted ? Date() : nil
                    updatedMessages.append(message)
                }

                try await messagesStore.storeMessages(updatedMessages)
            } catch {
                Log.error("Could not mark message as deleted == \(isDeleted): \(error)")
            }
        }
        
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

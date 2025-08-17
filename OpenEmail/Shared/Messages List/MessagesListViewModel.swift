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
    @Injected(\.client) private var client
    @ObservationIgnored
    @Injected(\.attachmentsManager) private var attachmentsManager
    
    private var allMessages: [Message] = []
    private var subscriptions = Set<AnyCancellable>()
    

    var threads: [MessageThread] = []
    
    var searchText: String = "" {
        didSet {
            Task {
                await reloadMessagesFromStore()
            }
        }
    }

    init() {
        NotificationCenter.default.publisher(for: .didSynchronizeMessages).sink { messages in
            Task {
                await self.reloadMessagesFromStore()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didUpdateMessages).sink { messages in
            Task {
                await self.reloadMessagesFromStore()
            }
        }.store(in: &subscriptions)
        
        
        Task {
            await reloadMessagesFromStore()
        }
        
    }
    
    @MainActor
    func reloadMessagesFromStore() async {
        if let localUser = LocalUser.current {
            Task {
                do {
                    allMessages = try await messagesStore
                        .allMessages(searchText: searchText)
                        .filteredBy(
                            scope: .messages
                        )
                    threads.removeAll()
                    
                    for message in allMessages {
                        if let existingThreadIndex = threads.firstIndex(where: { $0.subjectId == message.subjectId }) {
                            threads[existingThreadIndex].messages.append(message)
                        } else {
                            threads.append(MessageThread(subjectId: message.subjectId, messages: [message]))
                        }
                    }
                        //.map(MessageThread.init).sorted(by: { $0.lastMessageDate > $1.lastMessageDate }).forEach(\.id)
                    print("Threads: \(threads)")
                } catch {
                    Log.error("Could not get messages from store:", context: error)
                }
            }
        }
    }

    func markAsRead(threads: Set<MessageThread>) {
        //setReadState(messageIDs: messageIDs, isRead: true)
    }

    func markAsUnread(threads: Set<MessageThread>) {
       // setReadState(messageIDs: messageIDs, isRead: false)
    }
    
    func deletePermanently(threads: Set<MessageThread>) async {
//        await withTaskGroup { group in
//            for messageId in messageIDs {
//                group.addTask {
//                    do {
//                        try await self.messagesStore.deleteMessage(id: messageId)
//                    } catch {
//                        Log.error("Could not delete messages: \(error)")
//                    }
//                }
//            }
//            await group.waitForAll()
//        }
    }
    
    func markAsDeleted(messageIDs: Set<String>, isDeleted: Bool) async {
        guard let currentUser = LocalUser.current else {
            return
        }
        let messages = allMessages.filter { messageIDs.contains($0.id) }
        await withTaskGroup { group in
            for message in messages {
                var localMessage = message
                group.addTask {
                    do {
                        if isDeleted {
                            if localMessage.isOutbox() {
                                
                                try? await self.client
                                    .recallAuthoredMessage(
                                        localUser: currentUser,
                                        messageId: message.id
                                    )
                                
                                if localMessage.isDraft {
                                    try await self.messagesStore.deleteMessage(id: localMessage.id)
                                    return
                                } else {
                                    if var draftMessage = Message.draft(from: localMessage) {
                                        draftMessage.draftAttachmentUrls = try localMessage
                                            .copyAttachmentsToTempFolder(
                                                attachmentsManager: self.attachmentsManager
                                            )
                                        try await self.messagesStore.deleteMessage(id: localMessage.id)
                                        localMessage = draftMessage
                                    }
                                }
                            } else {
                                localMessage.deletedAt = Date()
                            }
                        } else {
                            localMessage.deletedAt = nil
                        }
                        try await self.messagesStore.storeMessage(localMessage)
                        
                    } catch {
                        Log.error("Could not mark message as deleted == \(isDeleted): \(error)")
                    }
                }
            }
            await group.waitForAll()
        }
    }
 

    private func setReadState(threads: Set<MessageThread>, isRead: Bool) {
//        Task {
//            do {
//                guard let localUser = LocalUser.current else { return }
//
//                var updatedMessages = [Message]()
//
//                for messageID in messageIDs {
//                    if let index = allMessages.firstIndex(where: { $0.id == messageID && $0.isRead != isRead }) {
//                        var message = allMessages[index]
//                        
//                        // setting read state on messages the user sent doesn't make sense
//                        guard message.author != localUser.address.address else { continue }
//
//                        message.isRead = isRead
//                        updatedMessages.append(message)
//
//                        allMessages[index] = message
//                    }
//                }
//
//                try await messagesStore.storeMessages(updatedMessages)
//            } catch {
//                Log.error("Could not mark message as read: \(error)")
//            }
//        }
    }
}

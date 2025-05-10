//
//  MessageDeletionUsecase.swift
//  OpenEmail
//
//  Created by Antony Akimchenko on 09.05.25.
//

import Logging
import OpenEmailCore
import OpenEmailModel
import Foundation

class MessageDeletionUsecase {
    
    @Injected(\.messagesStore) private var messagesStore
    @Injected(\.archivedMessagesStore) private var archivedMessagesStore
    @Injected(\.client) private var client
    
    func putToTrash(messageIDs: Set<String>) async {
        do {
            let messagesToDelete = try await messagesStore.allMessages(ids: Array(messageIDs))
            try await archivedMessagesStore.storeArchivedMessages(messagesToDelete)
            try await messagesStore.deleteMessages(ids: Array(messageIDs))
        } catch {
            Log.error("Could not put messages to trash store", context: error)
        }
    }
    
    func recallMessages(messagesIDs: Set<String>) async throws {
        guard let localUser = LocalUser.current else {
            return
        }
        
        let selectedMessages = try await messagesStore.allMessages(ids: Array(messagesIDs))
        
        await withTaskGroup { group in
            for message in selectedMessages {
                group.addTask {
                    do {
                        try await withThrowingTaskGroup { innerGroup in
                            innerGroup.addTask {
                                try await self.client.recallAuthoredMessage(localUser: localUser, messageId: message.id)
                            }
                            
                            let ids = message.attachments.flatMap { $0.fileMessageIds }
                            for id in ids {
                                innerGroup.addTask {
                                    try await self.client.recallAuthoredMessage(localUser: localUser, messageId: id)
                                }
                            }
                            
                            try await innerGroup.waitForAll()
                        }
                    } catch {
                        Log.error("Could not recall outbox message id: \(message.id)", context: error)
                    }
                }
            }
            await group.waitForAll()
        }
    }

    func restoreFromTrash(messageIDs: Set<String>) async {
        do {
            let messagesToRestore = try await archivedMessagesStore.allArchivedMessages(ids: Array(messageIDs))
            try await messagesStore.storeMessages(messagesToRestore)
            try await archivedMessagesStore.deleteArchivedMessages(ids: Array(messageIDs))
            
        } catch {
            Log.error("Could not restore messsages from trash", context: error)
        }
    }

    func deleteFromTrash(messageIDs: Set<String>) async {
        
        await withTaskGroup { group in
            for messageId in messageIDs {
                group.addTask {
                    do {
                        try await self.archivedMessagesStore
                            .deleteArchivedMessages(ids: Array(messageIDs))
                        if var modifiedMessage = try await self.archivedMessagesStore.archivedMessage(id: messageId) {
                            modifiedMessage.deletedAt = Date()
                            try await self.archivedMessagesStore.storeArchivedMessage(modifiedMessage)
                        }
                    } catch {
                        Log.error("Could not get mark as permanently deleted:", context: error)
                    }
                   
                }
            }
            await group.waitForAll()
        }
    }
}

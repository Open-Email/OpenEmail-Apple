import Foundation
import Observation
import SwiftUI
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence
import Utils
import Logging
import Combine

@Observable
class MessageThreadViewModel {
    @ObservationIgnored
    @Injected(\.client) private var client

    @ObservationIgnored
    @Injected(\.syncService) var syncService

    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore
    
    @ObservationIgnored
    @Injected(\.pendingMessageStore) private var pendingMessageStore

    @ObservationIgnored
    @Injected(\.attachmentsManager) private var attachmentsManager

    var messageThread: MessageThread?
    var allMessages: [UnifiedMessage] = []
    
    var editSubject: String = ""
    var editBody: String = ""
    var attachedFileItems: [AttachedFileItem] = []
    private var subscriptions = Set<AnyCancellable>()

    init(messageThread: MessageThread?) {
        self.messageThread = messageThread
        
        NotificationCenter.default.publisher(for: .didSynchronizeMessages).sink { messages in
            Task {
                await self.updateThread()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didUpdatePendingMessages).sink { messages in
            Task {
                await self.updateThread()
            }
        }.store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .didUpdateMessages).sink { messages in
            Task {
                await self.updateThread()
            }
        }.store(in: &subscriptions)
        
        Task {
            await updateThread()
        }
    }

    private func updateThread() async {
        let pendingMessages = try? await pendingMessageStore.allPendingMessages(searchText: "")
        
        let savedMessages = try? await messagesStore
            .allMessages(searchText: "")
            .filteredBy(
                scope: .messages
            ).filter { message in
                message.subjectId == self.messageThread?.subjectId
            }
        
        messageThread?.messages.removeAll()
        messageThread?.messages = savedMessages ?? []
        
        allMessages = (messageThread?.messages.map { .normal($0) } ?? []) +
        (pendingMessages ?? []).map { .pending($0) }
    }
    
    func clear() {
        attachedFileItems.removeAll()
        editSubject = ""
        editBody = ""
    }
    
    func permanentlyDeleteMessage(message: Message) async throws {
        try await messagesStore.deleteMessage(id: message.id)
    }

    func markAsDeleted(message: Message, deleted: Bool) async throws {
        if message.isOutbox() {
            try? await recallMessage(message: message)
            let _ = try await convertToDraft(message: message)
            try await messagesStore.deleteMessage(id: message.id)
        } else {
            try await messagesStore.markAsDeleted(message: message, deleted: deleted)
        }
    }
    
    func appendAttachedFiles(urls: [URL], preserveFilePath: Bool = false) {
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for url in urls {
                        group.addTask {
                            let sandboxUrl = preserveFilePath ? url : try await copyFileIntoSandbox(url)
                            if !self.attachedFileItems.contains(where: { sandboxUrl == $0.url }) {
                                let item = AttachedFileItem(url: sandboxUrl)
                                self.attachedFileItems.append(item)
                            }
                        }
                    }
                    
                    try await group.waitForAll()
                }
            } catch {
                Log.error(error)
            }
        }
    }

    private func recallMessage(message: Message) async throws {
        guard let localUser = LocalUser.current else {
            return
        }

        try await withThrowingTaskGroup { group in
            group.addTask {
                try await self.client.recallAuthoredMessage(localUser: localUser, messageId: message.id)
            }
            
            message.attachments.flatMap { $0.fileMessageIds }.forEach { attachmentId in
                group.addTask {
                    try await self.client.recallAuthoredMessage(localUser: localUser, messageId: attachmentId)
                }
            }
            try await group.waitForAll()
        }
        
       
    }

    private func convertToDraft(message: Message) async throws -> Message? {
        guard var draftMessage = Message.draft(from: message) else {
            return nil
        }

        draftMessage.draftAttachmentUrls = try message
            .copyAttachmentsToTempFolder(attachmentsManager: attachmentsManager)

        do {
            try await messagesStore.storeMessage(draftMessage)
        } catch {
            Log.error("Could not save draft: \(error)")
        }

        return draftMessage
    }
}

enum UnifiedMessage {
    case normal(Message)
    case pending(PendingMessage)
}

import Foundation
import Observation
import SwiftUI
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence
import Utils
import Logging

@Observable
class MessageViewModel {
    @ObservationIgnored
    @Injected(\.client) private var client

    @ObservationIgnored
    @Injected(\.syncService) var syncService

    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore

    @ObservationIgnored
    @Injected(\.attachmentsManager) private var attachmentsManager

    var messageID: String? {
        didSet {
            if messageID != nil {
                fetchMessage()
            } else {
                message = nil
                authorProfile = nil
                profileImage = nil
            }
        }
    }
    var message: Message?
    var authorProfile: Profile?
    var profileImage: OEImage?
    var isLoadingProfileImage = true
    var isRecalling = false
    var readers: [Profile] = []

    var showProgress: Bool {
        isRecalling
    }

    var allAttachmentsDownloaded: Bool {
        guard let message else { return false }

        return message.attachments
            .map { attachmentsManager.fileUrl(for: $0) != nil }
            .allSatisfy { $0 }
    }

    var recallInfoMessage: String {
        var info = "Discarding the message will remove it from your outbox and move it to the trash. It will no longer be accessible to readers."

        if !allAttachmentsDownloaded {
            info += "\n\nSome attachments haven't been downloaded. Once discarded, they will no longer be accessible."
        }

        return info
    }

    init(messageID: String?) {
        self.messageID = messageID
        fetchMessage()
    }

    func fetchMessage() {
        if let messageID {
            Task {
                await fetchMessage(messageID: messageID)
                
                let result: [Profile] = await withTaskGroup(of: Void.self, returning: [Profile].self) { group in
                    
                    var rv: [Profile] = []
                    
                    for address in message?.readers ?? [] {
                        group.addTask {
                            if let emailAddress = EmailAddress(address),
                               let profile = try? await self.client
                                .fetchProfile(
                                    address: emailAddress,
                                    force: false
                                ) {
                                rv.append(profile)
                            } 
                        }
                    }
                    await group.waitForAll()
                    return rv
                }
                readers = result
            }
        }
    }

    @MainActor
    private func fetchMessage(messageID: String) async {
        message = try? await messagesStore.message(id: messageID)

        Task { [self] in
            await fetchAuthorProfile()
        }
    }

    private func fetchAuthorProfile() async {
        guard
            let message,
            let emailAddress = EmailAddress(message.author)
        else {
            return
        }

        authorProfile = try? await client.fetchProfile(address: emailAddress, force: false)
    }

    func permanentlyDeleteMessage() async throws {
        try await messagesStore.deleteMessage(id: message!.id)
    }

    func markAsDeleted(_ deleted: Bool) async throws {
        guard let message else { return }
        if message.isOutbox() {
            try? await recallMessage()
            let _ = try await convertToDraft()
            try await messagesStore.deleteMessage(id: message.id)
        } else {
            try await messagesStore.markAsDeleted(message: message, deleted: deleted)
        }
    }

    private func recallMessage() async throws {
        guard let localUser = LocalUser.current, let message else {
            return
        }

        isRecalling = true

        do {
            try await client.recallAuthoredMessage(localUser: localUser, messageId: message.id)
            let ids = message.attachments.flatMap { $0.fileMessageIds }

            for id in ids {
                try await client.recallAuthoredMessage(localUser: localUser, messageId: id)
            }
            isRecalling = false
        } catch {
            isRecalling = false
            throw error
        }
    }

    private func convertToDraft() async throws -> Message? {
        guard let message else { return nil }
        guard var draftMessage = Message.draft(from: message) else {
            // TODO: throw error?
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

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
        try await client.recallAuthoredMessage(localUser: .current!, messageId: message!.id)
        try await message?.permentlyDelete(messageStore: messagesStore)
    }

    func markAsDeleted(_ deleted: Bool) async throws {
        guard let message else { return }
        try await messagesStore.markAsDeleted(message: message, deleted: deleted)
    }

    func recallMessage() async throws {
        guard let localUser = LocalUser.current, let message else {
            return
        }

        isRecalling = true

        do {
            try await client.recallAuthoredMessage(localUser: localUser, messageId: message.id)
            await syncService.recallMessageId(message.id)
            let ids = message.attachments.flatMap { $0.fileMessageIds }

            for id in ids {
                try await client.recallAuthoredMessage(localUser: localUser, messageId: id)
            }

            try await markAsDeleted(true)
            isRecalling = false
        } catch {
            isRecalling = false
            throw error
        }
    }

    func convertToDraft() async throws -> Message? {
        guard let message else { return nil }
        guard var draftMessage = Message.draft(from: message) else {
            // TODO: throw error?
            return nil
        }

        draftMessage.draftAttachmentUrls = try copyAttachmentsToTempFolder(message: message)

        do {
            try await messagesStore.storeMessage(draftMessage)
        } catch {
            Log.error("Could not save draft: \(error)")
        }

        return draftMessage
    }

    private func copyAttachmentsToTempFolder(message: Message) throws -> [URL] {
        let attachmentUrls = message.attachments.compactMap {
            attachmentsManager.fileUrl(for: $0)
        }

        guard !attachmentUrls.isEmpty else {
            return []
        }

        let fm = FileManager.default

        // create temp folder
        let tempAttachmentsLocation = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appending(path: message.id, directoryHint: .isDirectory)

        Log.debug("copying attachments to \(tempAttachmentsLocation)")

        try fm.createDirectory(at: tempAttachmentsLocation, withIntermediateDirectories: true)

        // copy attachments
        var urls = [URL]()
        for url in attachmentUrls {
            let detsination = tempAttachmentsLocation.appending(component: url.lastPathComponent)
            try fm.copyItem(at: url, to: detsination)
            urls.append(detsination)
        }

        return urls
    }
}

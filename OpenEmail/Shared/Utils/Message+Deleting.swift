import Foundation
import OpenEmailModel
import OpenEmailPersistence
import Utils

extension Message {
    func permentlyDelete(messageStore: MessageStoring) async throws {
        // delete from DB
        try await messageStore.deleteMessage(id: id)

        if !isDraft {
            // delete from disk
            let fm = FileManager.default
            let messageFolderUrl = fm.messagesFolderURL(userAddress: localUserAddress)
                .appendingPathComponent(id)

            try? fm.removeItem(at: messageFolderUrl)
        }
    }
}

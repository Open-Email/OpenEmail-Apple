import Foundation
import OpenEmailModel
import SwiftData

extension Message {
    func toPersisted(modelContext: ModelContext) -> PersistedMessage {
        let message = PersistedMessage(
            localUserAddress: localUserAddress,
            id: id,
            size: size,
            receivedOn: receivedOn,
            authoredOn: authoredOn,
            author: author,
            readers: readers,
            readersStr: readersStr,
            deliveries: deliveries,
            subject: subject,
            body: body,
            subjectId: subjectId,
            isBroadcast: isBroadcast, 
            accessKey: accessKey,
            isRead: isRead,
            deletedAt: deletedAt,
            draftAttachmentUrls: draftAttachmentUrls
        )

        modelContext.insert(message)

        message.attachments = attachments.map {
            $0.toPersisted(modelContext: modelContext)
        }

        return message
    }
}

extension PersistedMessage {
    func toLocal() -> Message {
        Message(
            localUserAddress: localUserAddress,
            id: id,
            size: size,
            authoredOn: authoredOn,
            receivedOn: receivedOn,
            author: author,
            readers: readers,
            deliveries: deliveries,
            subject: subject,
            body: body,
            subjectId: subjectId,
            isBroadcast: isBroadcast,
            accessKey: accessKey,
            isRead: isRead,
            deletedAt: deletedAt,
            attachments: attachments.map { $0.toLocal() },
            draftAttachmentUrls: draftAttachmentUrls
        )
    }
}

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
            accessKey: accessKey == nil ? nil : Data(accessKey!),
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
            readers: readers.split(separator: ",").map { subStr in String(subStr) },
            deliveries: deliveries.split(separator: ",").map { subStr in String(subStr) },
            subject: subject,
            body: body,
            subjectId: subjectId,
            isBroadcast: isBroadcast,
            accessKey: accessKey == nil ? nil : [UInt8](accessKey!),
            isRead: isRead,
            deletedAt: deletedAt,
            attachments: attachments.map { $0.toLocal() },
            draftAttachmentUrls: draftAttachmentUrls.split(separator: ",").map { subStr in URL(string : String(subStr))! }
        )
    }
}

import Foundation
import OpenEmailModel
import SwiftData

extension Attachment {
    func toPersisted(modelContext: ModelContext) -> PersistedAttachment {
        let attachment = PersistedAttachment(
            id: id,
            fileMessageIds: fileMessageIds,
            filename: filename,
            size: size,
            mimeType: mimeType
        )

        modelContext.insert(attachment)

        return attachment
    }
}

extension PersistedAttachment {
    func toLocal() -> Attachment {
        Attachment(
            id: id,
            parentMessageId: parentMessage?.id ?? "",
            fileMessageIds: fileMessageIds.split(separator: ",").map {substr in String(substr) },
            filename: filename,
            size: size,
            mimeType: mimeType
        )
    }
}

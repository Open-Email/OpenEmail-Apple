import Foundation
import OpenEmailModel

extension Message {
    static let wordGenerator = RandomWordGenerator.shared

    static func makeRandom(
        id: String = UUID().uuidString,
        isDraft: Bool = false,
        readers: [String] = ["donald@duck.com", "daisy@duck.com", "goofy@duck.com", "scrooge@duck.com"],
        subject: String? = nil,
        body: String? = nil,
        isBroadcast: Bool = false,
        isRead: Bool = false,
        attachments: [Attachment] = [.init(id: "123_disney.zip", parentMessageId: "123", fileMessageIds: ["234"], filename: "disney.zip", size: 19140497, mimeType: "application/zip")]
    ) -> Message {
        let subject = subject ?? wordGenerator.next(2).capitalized
        let body = body ?? wordGenerator.next(50) + "."

        let resolvedId = isDraft ? "draft_\(id)" : id

        return Message(
            localUserAddress: "mickey@mouse.com", 
            id: resolvedId,
            size: 0,
            authoredOn: .now, receivedOn: .now,
            author: "mickey@mouse.com",
            readers: isBroadcast ? [] : readers,
            subject: subject,
            body: body,
            subjectId: id,
            isBroadcast: isBroadcast,
            accessKey: nil,
            isRead: isRead,
            deletedAt: nil,
            attachments: attachments
        )
    }
}

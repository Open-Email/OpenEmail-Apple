import Foundation
import OpenEmailModel

public extension Message {
    static func draft() -> Message? {
        guard
            let localUser = LocalUser.current
        else {
            return nil
        }

        return Message(
            localUserAddress: localUser.address.address,
            id: "draft_\(UUID().uuidString)",
            size: 0,
            authoredOn: .now,
            receivedOn: .now,
            author: localUser.address.address,
            subject: "",
            subjectId: "",
            isBroadcast: false,
            accessKey: nil,
            isRead: true,
            deletedAt: nil, 
            attachments: []
        )
    }

    static func draft(from other: Message) -> Message? {
        if other.isDraft {
            return other
        }

        guard
            let localUser = LocalUser.current
        else {
            return nil
        }

        return Message(
            localUserAddress: localUser.address.address,
            id: "draft_\(UUID().uuidString)",
            size: other.size,
            authoredOn: .now,
            receivedOn: .now,
            author: localUser.address.address,
            readers: other.readers,
            subject: other.subject,
            body: other.body,
            subjectId: "",
            isBroadcast: other.isBroadcast,
            accessKey: nil,
            isRead: true,
            deletedAt: nil,
            attachments: []
        )
    }
}

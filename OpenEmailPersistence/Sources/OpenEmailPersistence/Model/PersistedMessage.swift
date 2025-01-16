import Foundation
import SwiftData

@Model
class PersistedMessage {
    @Attribute(.unique) var id: String
    var size: UInt64
    var authoredOn: Date
    var receivedOn: Date
    var author: String
    var readers: [String]
    var readersStr: String
    var deliveries: [String]
    var subject: String
    var body: String?
    var subjectId: String
    var isBroadcast: Bool
    var accessKey: [UInt8]?
    var localUserAddress: String
    var isRead: Bool
    var deletedAt: Date?
    var draftAttachmentUrls: [URL]

    @Relationship(deleteRule: .cascade, inverse: \PersistedAttachment.parentMessage)
    var attachments: [PersistedAttachment] = []

    init(
        localUserAddress:String,
        id: String,
        size: UInt64,
        receivedOn: Date,
        authoredOn: Date,
        author: String,
        readers: [String] = [],
        readersStr: String = "",
        deliveries: [String] = [],
        subject: String,
        body: String? = nil,
        subjectId: String,
        isBroadcast: Bool,
        accessKey: [UInt8]?,
        isRead: Bool,
        deletedAt: Date?,
        draftAttachmentUrls: [URL]
    ) {
        self.localUserAddress = localUserAddress
        self.id = id
        self.size = size
        self.authoredOn = authoredOn
        self.receivedOn = receivedOn
        self.author = author
        self.readers = readers
        self.readersStr = readersStr
        self.deliveries = deliveries
        self.subject = subject
        self.body = body
        self.subjectId = subjectId
        self.isRead = isRead
        self.deletedAt = deletedAt
        self.draftAttachmentUrls = draftAttachmentUrls
        self.isBroadcast = isBroadcast
        self.accessKey = accessKey
    }
}

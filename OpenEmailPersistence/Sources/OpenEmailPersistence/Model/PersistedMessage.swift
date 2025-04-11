import Foundation
import SwiftData

@Model
class PersistedMessage {
    @Attribute(.unique) var id: String
    var size: UInt64
    var authoredOn: Date
    var receivedOn: Date
    var author: String
    var readers: String // [String] jined with ","
    var readersStr: String
    var deliveries: String // [String] jined with ","
    var subject: String
    var body: String?
    var subjectId: String
    var isBroadcast: Bool
    var accessKey: Data?
    var localUserAddress: String
    var isRead: Bool
    var deletedAt: Date?
    var draftAttachmentUrls: String // [URL] jined with ","

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
        accessKey: Data?,
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
        self.readers = readers.joined(separator: ",")
        self.readersStr = readersStr
        self.deliveries = deliveries.joined(separator: ",")
        self.subject = subject
        self.body = body
        self.subjectId = subjectId
        self.isRead = isRead
        self.deletedAt = deletedAt
        self.draftAttachmentUrls = draftAttachmentUrls
            .map { url in url.absoluteString }.joined(separator: ",")
        self.isBroadcast = isBroadcast
        self.accessKey = accessKey
    }
}

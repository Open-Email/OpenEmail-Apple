import Foundation
import Utils

public struct Message: Identifiable, Equatable {
    public let id: String
    public let authoredOn: Date
    public let receivedOn: Date
    public let author: String
    public var readers: [String]
    public var subject: String
    public let subjectId: String
    public let localUserAddress: String
    public var isBroadcast: Bool
    public let accessKey: [UInt8]?

    public var body: String?
    public var deliveries: [String] // addresses that have fetched the message
    public var size: UInt64
    public var isRead: Bool
    public var deletedAt: Date?

    public var attachments: [Attachment]
    public var draftAttachmentUrls: [URL]

    public var hasFiles: Bool {
        attachments.isEmpty == false
    }

    public var isDraft: Bool {
        id.hasPrefix("draft_")
    }

    public var isDeleted: Bool {
        deletedAt != nil
    }

    public var readersStr: String {
        readers.joined(separator: ",")
    }

    public init(
        localUserAddress: String,
        id: String,
        size: UInt64,
        authoredOn: Date,
        receivedOn: Date,
        author: String,
        readers: [String] = [],
        deliveries: [String] = [],
        subject: String,
        body: String? = nil,
        subjectId: String,
        isBroadcast: Bool,
        accessKey: [UInt8]?,
        isRead: Bool,
        deletedAt: Date?,
        attachments: [Attachment],
        draftAttachmentUrls: [URL] = []
    ) {
        self.localUserAddress = localUserAddress
        self.id = id
        self.size = size
        self.authoredOn = authoredOn
        self.receivedOn = receivedOn
        self.author = author
        self.readers = readers
        self.deliveries = deliveries
        self.subject = subject
        self.body = body
        self.subjectId = subjectId
        self.isRead = isRead
        self.deletedAt = deletedAt
        self.attachments = attachments
        self.draftAttachmentUrls = draftAttachmentUrls
        self.isBroadcast = isBroadcast
        self.accessKey = accessKey
    }
}

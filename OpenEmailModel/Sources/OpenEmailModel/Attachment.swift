import Foundation

public struct Attachment: Identifiable, Equatable {
    public let id: String
    public let parentMessageId: String
    public let fileMessageIds: [String]

    public var filename: String
    public var size: UInt64
    public var mimeType: String

    public init(
        id: String,
        parentMessageId: String,
        fileMessageIds: [String],
        filename: String,
        size: UInt64,
        mimeType: String
    ) {
        self.id = id
        self.parentMessageId = parentMessageId
        self.fileMessageIds = fileMessageIds
        self.filename = filename
        self.size = size
        self.mimeType = mimeType
    }
}

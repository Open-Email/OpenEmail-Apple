import Foundation
import SwiftData

@Model
class PersistedAttachment {
    @Attribute(.unique) var id: String

    var parentMessage: PersistedMessage?
    var fileMessageIds: [String]

    var filename: String
    var size: UInt64
    var mimeType: String

    init(
        id: String,
        fileMessageIds: [String],
        filename: String,
        size: UInt64,
        mimeType: String
    ) {
        self.id = id
        self.fileMessageIds = fileMessageIds
        self.filename = filename
        self.size = size
        self.mimeType = mimeType
    }
}

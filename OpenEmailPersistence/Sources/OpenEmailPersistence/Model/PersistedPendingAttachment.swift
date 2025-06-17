//
//  PersistedPendingAttachment.swift
//  OpenEmailPersistence
//
//  Created by Antony Akimchenko on 14.06.25.
//

import Foundation
import SwiftData

@Model
class PersistedPendingAttachment {
    @Attribute(.unique) var id: String
    
    var parentMessage: PersistedPendingMessage?
    var fileMessageIds: String // [String] joined with ","
    
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
        self.fileMessageIds = fileMessageIds.joined(separator: ",")
        self.filename = filename
        self.size = size
        self.mimeType = mimeType
    }
}

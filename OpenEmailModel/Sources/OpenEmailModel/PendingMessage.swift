//
//  PendingMessage.swift
//  OpenEmailModel
//
//  Created by Antony Akimchenko on 14.06.25.
//

import Foundation

public struct PendingMessage {
    public let id: String
    public let authoredOn: Date
    public let readers: [String]
    public let subject: String
    public let subjectId: String?
    public let isBroadcast: Bool
    public let body: String?
    public let draftAttachmentUrls: [URL]
    
    public var hasFiles: Bool {
        draftAttachmentUrls.isEmpty == false
    }
    
    public init(
        id: String,
        authoredOn: Date,
        readers: [String],
        draftAttachmentUrls: [URL],
        subject: String,
        subjectId: String?,
        body: String,
        isBroadcast: Bool,
    ) {
        self.id = id
        self.authoredOn = authoredOn
        self.readers = readers
        self.subject = subject
        self.subjectId = subjectId
        self.body = body
        self.draftAttachmentUrls = draftAttachmentUrls
        self.isBroadcast = isBroadcast
    }
}

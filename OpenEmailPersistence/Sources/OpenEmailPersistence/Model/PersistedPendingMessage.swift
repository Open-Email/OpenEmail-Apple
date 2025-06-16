//
//  PersistedPendingMessage.swift
//  OpenEmailPersistence
//
//  Created by Antony Akimchenko on 14.06.25.
//
import Foundation
import SwiftData

@Model
class PersistedPendingMessage {
    @Attribute(.unique) var id: String
    var authoredOn: Date
    var author: String
    var readers: String // [String] jined with ","
    var readersStr: String
    var deliveries: String // [String] jined with ","
    var subject: String
    var body: String?
    var isBroadcast: Bool
    var draftAttachmentUrls: String // [URL] jined with ","
    
    @Relationship(deleteRule: .cascade, inverse: \PersistedPendingAttachment.parentMessage)
    var attachments: [PersistedPendingAttachment] = []
    
    init(
        id: String,
        authoredOn: Date,
        author: String,
        readers: [String] = [],
        readersStr: String = "",
        deliveries: [String] = [],
        subject: String,
        body: String? = nil,
        isBroadcast: Bool,
        draftAttachmentUrls: [URL]
    ) {
        self.id = id
        self.authoredOn = authoredOn
        self.author = author
        self.readers = readers.joined(separator: ",")
        self.readersStr = readersStr
        self.deliveries = deliveries.joined(separator: ",")
        self.subject = subject
        self.body = body
        self.draftAttachmentUrls = draftAttachmentUrls
            .map { url in url.absoluteString }.joined(separator: ",")
        self.isBroadcast = isBroadcast
    }
}

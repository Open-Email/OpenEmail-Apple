//
//  PendingMessage+Conversion.swift
//  OpenEmailPersistence
//
//  Created by Antony Akimchenko on 16.06.25.
//

import Foundation
import OpenEmailModel
import SwiftData

extension PendingMessage {
    func toPersisted() -> PersistedPendingMessage {
        return PersistedPendingMessage(
            id: id,
            authoredOn: authoredOn,
            author: author,
            readers: readers,
            subject: subject,
            body: body,
            isBroadcast: isBroadcast,
            draftAttachmentUrls: draftAttachmentUrls
        )
    }
}

extension PersistedPendingMessage {
    func toLocal() -> PendingMessage {
        PendingMessage(
            id: id,
            author: author,
            authoredOn: authoredOn,
            readers: readers.split(separator: ",").map { subStr in String(subStr) },
            draftAttachmentUrls: draftAttachmentUrls.split(separator: ",").map { subStr in URL(string : String(subStr))! },
            subject: subject,
            body: body,
            isBroadcast: isBroadcast
        )
    }
}

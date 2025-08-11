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
            readers: readers,
            subject: subject,
            subjectId: subjectId,
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
            authoredOn: authoredOn,
            readers: readers.split(separator: ",").map { subStr in String(subStr) },
            draftAttachmentUrls: draftAttachmentUrls.split(separator: ",").map { subStr in URL(string : String(subStr))! },
            subject: subject,
            subjectId: subjectId,
            body: body ?? "",
            isBroadcast: isBroadcast
        )
    }
}

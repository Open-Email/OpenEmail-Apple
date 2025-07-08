import Foundation
import OpenEmailModel
import Logging

public extension Message {
    static func draft() -> Message? {
        guard
            let localUser = LocalUser.current
        else {
            return nil
        }

        return Message(
            localUserAddress: localUser.address.address,
            id: "draft_\(UUID().uuidString)",
            size: 0,
            authoredOn: .now,
            receivedOn: .now,
            author: localUser.address.address,
            subject: "",
            subjectId: "",
            isBroadcast: false,
            accessKey: nil,
            isRead: true,
            deletedAt: nil, 
            attachments: []
        )
    }

    static func draft(from other: Message) -> Message? {
        if other.isDraft {
            return other
        }

        guard
            let localUser = LocalUser.current
        else {
            return nil
        }

        return Message(
            localUserAddress: localUser.address.address,
            id: "draft_\(UUID().uuidString)",
            size: other.size,
            authoredOn: .now,
            receivedOn: .now,
            author: localUser.address.address,
            readers: other.readers,
            subject: other.subject,
            body: other.body,
            subjectId: "",
            isBroadcast: other.isBroadcast,
            accessKey: nil,
            isRead: true,
            deletedAt: nil,
            attachments: []
        )
    }
    
    func copyAttachmentsToTempFolder(attachmentsManager: AttachmentsManager) throws -> [URL] {
        let attachmentUrls = attachments.compactMap {
            attachmentsManager.fileUrl(for: $0)
        }
        
        guard !attachmentUrls.isEmpty else {
            return []
        }
        
        let fm = FileManager.default
        
        // create temp folder
        let tempAttachmentsLocation = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appending(path: id, directoryHint: .isDirectory)
        
        Log.debug("copying attachments to \(tempAttachmentsLocation)")
        
        try fm.createDirectory(at: tempAttachmentsLocation, withIntermediateDirectories: true)
        
        // copy attachments
        var urls = [URL]()
        for url in attachmentUrls {
            let detsination = tempAttachmentsLocation.appending(component: url.lastPathComponent)
            try fm.copyItem(at: url, to: detsination)
            urls.append(detsination)
        }
        
        return urls
    }
}

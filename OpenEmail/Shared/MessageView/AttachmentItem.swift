//
//  AttachmentItem.swift
//  OpenEmail
//
//  Created by Antony Akimchenko on 15.09.25.
//

import Foundation
import OpenEmailModel
import Utils
#if canImport(UIKit)
import UIKit
#else
import AppKit
import UniformTypeIdentifiers
#endif

struct AttachmentItem: Identifiable {
    var id: String { attachment?.id ?? draftFileUrl?.path() ?? UUID().uuidString }
    
    let localUserAddress: String
    let attachment: Attachment?
    let isAvailable: Bool
    let isDraft: Bool
    let formattedFileSize: String?
    let icon: OEImage
    let draftFileUrl: URL?
    
    var locations: [URL] {
        guard let attachment else { return [] }
        
        let messagesDirectoryUrl = FileManager.default.documentsDirectoryUrl()
            .appendingPathComponent(MESSAGES_DIRECTORY)
            .appendingPathComponent(localUserAddress)
        return attachment.fileMessageIds.map {
            messagesDirectoryUrl
                .appendingPathComponent(attachment.parentMessageId)
                .appendingPathComponent("\($0).\(PAYLOAD_FILENAME)")
        }
    }
    
    var displayName: String {
        attachment?.filename.removingPercentEncoding ?? draftFileUrl?.lastPathComponent ?? ""
    }
}

extension Attachment {
    var fileIcon: OEImage {
#if canImport(AppKit)
        guard let type = UTType(mimeType: mimeType) else {
            return NSWorkspace.shared.defaultFileIcon
        }
        
        return NSWorkspace.shared.icon(for: type)
#else
        return UIImage.iconForMimeType(mimeType)
#endif
    }
}

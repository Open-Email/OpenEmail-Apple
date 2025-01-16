import Foundation

#if canImport(AppKit)
import AppKit

public extension NSWorkspace {
    var defaultFileIcon: NSImage {
        icon(for: .item)
    }
}

#else
import UIKit
import UniformTypeIdentifiers

public extension UIImage {
    static let defaultFileIcon = UIImage(systemName: "doc")!

    static func iconForPath(_ filePath: String) -> UIImage {
        return iconForFileURL(URL(fileURLWithPath: filePath))
    }

    static func iconForFileURL(_ url: URL) -> UIImage {
        let docController = UIDocumentInteractionController(url: url)
        return docController.icons.first ?? UIImage.defaultFileIcon
    }

    static func iconForMimeType(_ mimeType: String) -> UIImage {
        if let utType = UTType(mimeType: mimeType) {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp.\(utType.preferredFilenameExtension ?? "")")
            return iconForFileURL(tempURL)
        }
        return .defaultFileIcon
    }
}
#endif

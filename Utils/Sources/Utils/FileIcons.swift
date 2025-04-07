import Foundation
import QuickLookThumbnailing
import UniformTypeIdentifiers

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
    
    static func thumbnail(
            forFileAt url: URL,
            size: CGSize,
            scale: CGFloat = UIScreen.main.scale,
            completion: @escaping (UIImage?) -> Void
        ) {
            let scale = scale
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: size,
                scale: scale,
                representationTypes: .icon
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(
                for: request
            ) { (thumbnail, error) in
                guard let cgImage = thumbnail?.cgImage else {
                    completion(.defaultFileIcon)
                    return
                }
                completion(UIImage(cgImage: cgImage))
            }
        }
}
#endif

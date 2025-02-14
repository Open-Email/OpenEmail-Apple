import Foundation
import Logging
import UIKit
import UniformTypeIdentifiers

enum AttachmentsError: Error {
    case invalidImageData
    case fileStorageFailed
}

@Observable
class ComposeAttachmentsListViewModel {
    var attachedFileItems: [AttachedFileItem] = []

    @ObservationIgnored
    var messageId: String = ""

    private var addedImageCount = 0

    func attachmentItem(withId id: AttachedFileItem.ID) -> AttachedFileItem? {
        attachedFileItems.first { $0.id == id }
    }

    func addAttachmentItem(from imageData: Data) async throws {
        guard
            let image = UIImage(data: imageData)
        else {
            Log.error("Could not get image data")
            throw AttachmentsError.invalidImageData
        }

        let filename = "image\(addedImageCount)"

        let url: URL

        if
            let utTypeString = image.cgImage?.utType,
            let utType = UTType(utTypeString as String)
        {
            url = try saveTemporaryImage(data: imageData, utType: utType, filename: filename)
        } else {
            // fall back to png
            Log.warning("Could not determine type of image – falling back to PNG")

            guard let pngData = image.pngData() else {
                Log.error("Could not get PNG data")
                throw AttachmentsError.invalidImageData
            }

            url = try saveTemporaryImage(data: pngData, utType: .png, filename: filename)
        }

        addedImageCount += 1

        let item = AttachedFileItem(url: url)
        attachedFileItems.append(item)
    }

    func removeAttachmentItem(_ item: AttachedFileItem) {
        attachedFileItems.removeAll {
            $0.url == item.url
        }
    }

    private func saveTemporaryImage(data: Data, utType: UTType, filename: String) throws -> URL {
        let fm = FileManager.default

        let tempUrl = fm.temporaryDirectory
            .appendingPathComponent("attachments", isDirectory: true)
            .appendingPathComponent(messageId, isDirectory: true)

        var fileUrl = tempUrl.appendingPathComponent(filename)
        if let preferredFilenameExtension = utType.preferredFilenameExtension {
            fileUrl = fileUrl.appendingPathExtension(preferredFilenameExtension)
        }

        try fm.createDirectory(at: tempUrl, withIntermediateDirectories: true)
        if fm.createFile(atPath: fileUrl.path(), contents: data) {
            Log.debug("successfully stored temporary attachment")
            return fileUrl
        } else {
            throw AttachmentsError.fileStorageFailed
        }
    }
}

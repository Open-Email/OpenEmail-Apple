import Foundation

extension URL {
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: path(percentEncoded: false))
    }

    var fileSize: Int64? {
        let path = self.path(percentEncoded: false)

        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: path),
            let size = (attributes[.size] as? NSNumber)?.int64Value
        else {
            return nil
        }

        return size
    }

    var formattedFileSie: String? {
        guard let fileSize else { return nil}
        return Formatters.fileSizeFormatter.string(fromByteCount: Int64(fileSize))
    }
}

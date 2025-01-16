import Foundation
import Logging

extension FileManager {
    func sizeOfFile(at url: URL) -> UInt64? {
        do {
            let fileAttributes = try attributesOfItem(atPath: url.path)
            return fileAttributes[.size] as? UInt64
        } catch {
            Log.error("Error getting file size:", context: error)
            return nil
        }
    }
}

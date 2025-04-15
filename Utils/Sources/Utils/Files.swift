import Foundation
import Logging


public func copyFile(src: URL, dst: URL) throws {
    guard dst.startAccessingSecurityScopedResource() else {
        Log.error("🔒 Couldn't access user-selected folder")
        return
    }
    defer { dst.stopAccessingSecurityScopedResource() }
    
    let fm = FileManager.default
    
    if fm.fileExists(atPath: dst.path) {
        try fm.removeItem(at: dst)
    }
    
    try fm.copyItem(at: src, to: dst)
}

public func concatenateFiles(at locations: [URL], to destinationURL: URL) throws {
    let fileManager = FileManager.default

    // Ensure the destination file is cleared if it exists, or create an empty file to start with.
    if fileManager.fileExists(atPath: destinationURL.path) {
        try fileManager.removeItem(at: destinationURL)
    }
    fileManager.createFile(atPath: destinationURL.path, contents: nil, attributes: nil)

    // Open the destination file for appending data
    let fileHandle = try FileHandle(forWritingTo: destinationURL)

    for location in locations {
        let fileData = try Data(contentsOf: location)
        // Append the data to the destination file
        fileHandle.write(fileData)
    }

    // Close the file handle
    fileHandle.closeFile()
}

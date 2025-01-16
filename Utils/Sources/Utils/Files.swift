import Foundation

public func copyBytes(from sourceURL: URL, to destinationURL: URL, offset: UInt64, bytesCount: Int) throws {
    let fileManager = FileManager.default

    // Ensure the source file exists
    guard fileManager.fileExists(atPath: sourceURL.path) else {
        throw NSError(domain: "CopyBytesError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Source file does not exist"])
    }

    // Create the destination file if it does not exist
    if !fileManager.fileExists(atPath: destinationURL.path) {
        fileManager.createFile(atPath: destinationURL.path, contents: nil, attributes: nil)
    }

    // Open the source file for reading
    let isSourceSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
    let sourceFileHandle = try FileHandle(forReadingFrom: sourceURL)
    defer {
        if isSourceSecurityScoped {
            sourceURL.stopAccessingSecurityScopedResource()
        }
        sourceFileHandle.closeFile()
    }

    // Seek to the specified offset
    sourceFileHandle.seek(toFileOffset: offset)

    // Read the specified number of bytes
    let data = sourceFileHandle.readData(ofLength: bytesCount)

    // Open the destination file for writing
    let isDestinationSecurityScoped = destinationURL.startAccessingSecurityScopedResource()
    let destinationFileHandle = try FileHandle(forWritingTo: destinationURL)
    defer {
        if isDestinationSecurityScoped {
            destinationURL.stopAccessingSecurityScopedResource()
        }
        destinationFileHandle.closeFile()
    }

    // Write the data to the destination file
    destinationFileHandle.write(data)
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

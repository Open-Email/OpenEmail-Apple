import UniformTypeIdentifiers

extension NSURL {
    func mimeType() -> String {
        if let pathExt = self.pathExtension,
            let mimeType = UTType(filenameExtension: pathExt)?.preferredMIMEType {
            return mimeType
        }
        else {
            return "application/octet-stream"
        }
    }
}

extension URL {
    func mimeType() -> String {
        if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
            return mimeType
        }
        else {
            return "application/octet-stream"
        }
    }
}

extension NSString {
    func mimeType() -> String {
        if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
            return mimeType
        }
        else {
            return "application/octet-stream"
        }
    }
}

extension String {
    func mimeType() -> String {
        return (self as NSString).mimeType()
    }
}

import Foundation

public enum RegistrationError: Error {
    case accountAlreadyExists
    case provisioningError
}

public enum APIError: Error {
    case badEndpoint
    case authentication
    case undefined
}

public enum ParsingError: Error {
    case badLinkAttributesStructure
    case badHeaderFormat
    case badChecksum
    case badSignature
    case badContentHeaders
    case badMessageID
    case badResponse
    case badAccessLinks
    case envelopeAuthenticityFailure
    case tooLargeEnvelope
    case badPayloadSize
    case badReaderAddress
}

public enum LocalError: Error {
    case fileCopyingError
    case fileAccessError
    case accountError
}

public enum MessageError: Error {
    case notFound
    case emptyMessage
    case noValidReaders
    case inaccessibleReaders
    case missingReaders
    case missingAuthor
    case missingMessageID
    case missingContentHeadersData
    case noFileURLs
    case noHostnames
    case invalidParentMessage
}

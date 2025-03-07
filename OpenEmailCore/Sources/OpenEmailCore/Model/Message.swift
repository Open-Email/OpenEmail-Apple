import Foundation
import CryptoKit
import Logging
import Utils
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

public struct URLInfo {
    public let url: URL?
    public let name: String
    public let mimeType: String
    public let size: UInt64
    public let modifedAt: Date

    init(url: URL?, name: String, mimeType: String, size: UInt64, modifedAt: Date) {
        self.url = url
        self.name = name
        self.mimeType = mimeType
        self.size = size
        self.modifedAt = modifedAt
    }
}

public struct MessageFilePartInfo {
    public let urlInfo: URLInfo
    public let messageId: String
    public let part: UInt64
    public let size: UInt64
    public let checksum: String?
    public let offset: UInt64?
    public let totalParts: UInt64

    init(urlInfo: URLInfo, messageId: String, part: UInt64, size: UInt64, checksum: String? = nil, offset: UInt64? = nil, totalParts: UInt64) {
        self.urlInfo = urlInfo
        self.messageId = messageId
        self.part = part
        self.size = size
        self.checksum = checksum
        self.offset = offset
        self.totalParts = totalParts
    }
}

public struct MessageFileInfo {
    public let name: String
    public let mimeType: String
    public let size: UInt64
    public let modifedAt: Date
    public let messageIds: [String]
    public let complete: Bool

    public init(name: String, mimeType: String, size: UInt64, modifedAt: Date, messageIds: [String], complete: Bool) {
        self.name = name
        self.mimeType = mimeType
        self.size = size
        self.modifedAt = modifedAt
        self.messageIds = messageIds
        self.complete = complete
    }
}

#if canImport(AppKit)
public extension MessageFileInfo {
    var fileIcon: NSImage {
        if let type = UTType(mimeType: mimeType) {
            return NSWorkspace.shared.icon(for: type)
        }
        return NSWorkspace.shared.defaultFileIcon
    }
}
#else
public extension MessageFileInfo {
    var fileIcon: UIImage {
        UIImage.iconForMimeType(mimeType)
    }
}
#endif

enum MessageCategory: String {
    case personal // default
    case chat
    case transitory
    case notification
    case transaction
    case promotion
    case letter
    case file
    case informational
    case pass
    case funds
    case encryptionKey  // TODO: from encryption-key ?
    case signingKey     // TODO: from signing-key ?
}

struct Envelope {
    var CHECKSUM_HEADERS:[String] {
        return [HEADER_MESSAGE_ID,HEADER_MESSAGE_STREAM, HEADER_MESSAGE_ACCESS, HEADER_MESSAGE_HEADERS, HEADER_MESSAGE_ENCRYPTION]
    }

    let MAX_HEADERS_SIZE = 512 * 1024


    private let localUser: LocalUser

    // When fetching remote messages, we need the author profile
    var authorProfile: Profile?

    var messageID: String?

    var accessLinks: String?

    var streamId: String?

    var accessKey: [UInt8]?

    var payloadCipher: String?
    var payloadCipherInfo: PayloadSeal?

    var headersOrder: String?
    var headersChecksum: String?
    var headersSignature: String?

    var contentHeaders: ContentHeaders?
    var contentHeadersBytes: [UInt8]?

    var envelopeHeadersMap:[String:String] = [:]
    var envelopeData = Data()

    private var totalHeadersSize = 0

    // Reading a remote message
    init(messageID: String,  localUser: LocalUser, authorProfile: Profile) {
        self.localUser = localUser
        self.authorProfile = authorProfile
        self.messageID = messageID
    }

    // Composing a message
    init(localUser: LocalUser, contentHeaders: ContentHeaders) {
        self.localUser = localUser
        self.contentHeaders = contentHeaders
    }

    mutating func assignHeaderValue(key: String, value: String) throws {
        let key = key.lowercased()
        if !key.hasPrefix(HEADER_PREFIX) {
            return
        }
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        totalHeadersSize += key.count + value.count
        if totalHeadersSize > MAX_HEADERS_SIZE {
            throw ParsingError.tooLargeEnvelope
        }

        switch key {
        case HEADER_MESSAGE_ID:
            guard messageID == value else {
                throw ParsingError.badMessageID
            }

        case HEADER_MESSAGE_STREAM:
            streamId = value

        case HEADER_MESSAGE_ACCESS:
            accessLinks = value
            try parseAccessLink()

        case HEADER_MESSAGE_ACCESS:
            accessLinks = value

        case HEADER_MESSAGE_HEADERS:
            let contentHeaderMap = Envelope.parseHeaderAttributes(header: value)
            if let algorithm = contentHeaderMap["algorithm"] {
                if algorithm != Crypto.SYMMETRIC_CIPHER {
                    // no need to store it, it is assumed it is encrypted on private messages
                    throw CryptoError.algorithmMismatch
                }
            }
            if let data = contentHeaderMap["value"],
               let contentBytes = Crypto.base64decode(data) {
                contentHeadersBytes = contentBytes
            }

        case HEADER_MESSAGE_ENVELOPE_CHECKSUM:
            let checksumMap = Envelope.parseHeaderAttributes(header: value)
            if let algorithm = checksumMap["algorithm"],
                let sum = checksumMap["value"],
                let order = checksumMap["order"] {
                if algorithm.lowercased() != Crypto.CHECKSUM_ALGORITHM {
                    throw CryptoError.algorithmMismatch
                }
                headersOrder = order
                headersChecksum = sum
            } else {
                throw ParsingError.badChecksum
            }

        case HEADER_MESSAGE_ENVELOPE_SIGNATURE:
            let sigMap = Envelope.parseHeaderAttributes(header: value)
            if let algorithm = sigMap["algorithm"],
                let data = sigMap["value"] {
                if algorithm.lowercased() != Crypto.SIGNING_ALGORITHM {
                    throw CryptoError.algorithmMismatch
                }
                headersSignature = data
            }

        case HEADER_MESSAGE_ENCRYPTION:
            payloadCipher = value
            payloadCipherInfo = try cipherInfoFromHeader(headerValue: value)

        default:
            Log.warning("Unknown header:", context: "\(key): \(value)")
            return
        }
        envelopeHeadersMap[key] = value

        envelopeData.append(contentsOf: "\(key): \(value)\n".bytes)
    }

    mutating func openContentHeaders() throws {
        guard let headersBytes = contentHeadersBytes else {
            throw ParsingError.badContentHeaders
        }
        if isBroadcast() {
            guard let text = String(bytes: headersBytes, encoding: .utf8) else {
                throw ParsingError.badContentHeaders
            }
            self.contentHeaders = try contentFromHeaders(headersText: text)
            return
        }

        guard 
            let accessKey,
            let decryptedContentHeaders = String(bytes: try Crypto.decrypt_xchacha20poly1305(cipherData: headersBytes, secretKey: accessKey), encoding: .utf8)
        else {
            throw CryptoError.badAccessKey
        }
        self.contentHeaders = try contentFromHeaders(headersText: decryptedContentHeaders)
    }

    // Broadcast messages
    mutating func sealContentHeaders() throws {
        guard let headers = contentHeaders,
              isBroadcast() else {
            throw ParsingError.badContentHeaders
        }
        self.messageID = headers.messageID
        self.contentHeadersBytes = headers.contentHeadersText.bytes
    }

    // Private messages
    mutating func embedPrivateContentHeaders(accessKey: [UInt8], accessProfilesMap: [String:Profile]) throws {
        guard let headers = contentHeaders else {
            throw ParsingError.badContentHeaders
        }

        self.messageID = headers.messageID
        self.accessKey = accessKey

        var accessLinksList:[String] = []
        for (emailAddress, profile) in accessProfilesMap {
            if let pubEncryptionKey = profile[.encryptionKey],
               let pubSigningKey = profile[.signingKey],
               let pubEncKeyData = Crypto.base64decode(pubEncryptionKey),
               let pubEncKeyId = profile.encryptionKeyId,
               let pubSignKeyData = Crypto.base64decode(pubSigningKey) {
                let link = localUser.connectionLinkFor(remoteAddress: emailAddress)
                let accessKeyFingerprint = Crypto.publicKeyFingerprint(publicKey: pubSignKeyData)
                let accessKeyEncrypted = try Crypto.encryptAnonymous(data: accessKey, publicKey: pubEncKeyData)
                accessLinksList.append(Envelope.accessLinkGroup(link: link, accessKeyFingerprint: accessKeyFingerprint, accessKeyEncrypted: accessKeyEncrypted, encryptionKeyId: pubEncKeyId))
            }
        }
        self.accessLinks = accessLinksList.joined(separator: ", ")
        self.contentHeadersBytes = try Crypto.encrypt_xchacha20poly1305(plainText: headers.contentHeadersText.bytes, secretKey: accessKey)
    }

    mutating func embedBroadcastContentHeaders() throws {
        guard let headers = contentHeaders else {
            throw ParsingError.badContentHeaders
        }
        self.messageID = headers.messageID
        self.contentHeadersBytes = headers.contentHeadersText.bytes
    }


    mutating func seal(payloadSeal: PayloadSeal?) throws {
        envelopeHeadersMap = [:]

        guard let messageID = messageID else {
            throw MessageError.missingMessageID
        }
        envelopeHeadersMap[HEADER_MESSAGE_ID] = messageID

        guard let contentHeadersBytes = contentHeadersBytes else {
            throw MessageError.missingContentHeadersData
        }
        let contentHeadersEncoded = Crypto.base64encode(contentHeadersBytes)

        if let streamId = streamId {
            envelopeHeadersMap[HEADER_MESSAGE_STREAM] = streamId
        }

        if isBroadcast() {
            envelopeHeadersMap[HEADER_MESSAGE_HEADERS] = "value=\(contentHeadersEncoded)"
        } else {
            guard let payloadSeal = payloadSeal else {
                throw CryptoError.cipherInfoMissing
            }
            envelopeHeadersMap[HEADER_MESSAGE_ENCRYPTION] = payloadSeal.toHeader()
            envelopeHeadersMap[HEADER_MESSAGE_ACCESS] = accessLinks
            envelopeHeadersMap[HEADER_MESSAGE_HEADERS] = "algorithm=\(Crypto.SYMMETRIC_CIPHER); value=\(contentHeadersEncoded)"
        }
        // add the key so it is included in the .keys of the map
        let headerKeys = envelopeHeadersMap.keys.sorted()

        var headerValue = ""
        for hKey in headerKeys {
            if let value = envelopeHeadersMap[hKey],
               value != "" {
                headerValue = headerValue + value
            }
        }

        let (envelopeSum, sumData) = Crypto.checksum(data: Data(headerValue.bytes))
        envelopeHeadersMap[HEADER_MESSAGE_ENVELOPE_CHECKSUM] = "algorithm=\(Crypto.CHECKSUM_ALGORITHM); order=\(headerKeys.joined(separator: ":")); value=\(envelopeSum)"
        let signedChecksum = try Crypto.signData(publicKey: localUser.publicSigningKey, privateKey: localUser.privateSigningKey, data: sumData)

        envelopeHeadersMap[HEADER_MESSAGE_ENVELOPE_SIGNATURE] = "algorithm=\(Crypto.SIGNING_ALGORITHM); value=\(signedChecksum); id=\(localUser.publicEncryptionKeyId)"
    }

    func dumpHeaderData() -> Data {
        return Data(
            envelopeHeadersMap.map { "\($0): \($1)" }
                .joined(separator: "\n")
                .bytes
        )
    }

    func isBroadcast() -> Bool {
        if let accessLinks = accessLinks,
           !accessLinks.isEmpty {
            return false
        }
        return true
    }

    func assertEnvelopeAuthenticity() throws {
        var headerData = Data()
        // If the three are net present, it's pointless to check further
        guard let authorProfile = authorProfile else {
            throw MessageError.missingAuthor
        }
        guard  let headersOrder = headersOrder,
              let headersChecksum = headersChecksum,
              headersSignature != nil else {
            throw ParsingError.envelopeAuthenticityFailure
        }
        for headerKey in headersOrder.lowercased().split(separator: ":").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
            if CHECKSUM_HEADERS.contains(headerKey) {
                if let value = envelopeHeadersMap[headerKey] {
                    headerData.append(contentsOf: value.bytes)
                }
            }
        }

        // Verify headers checksum
        let (headersSum, headersSumBytes) = Crypto.checksum(data: headerData)
        if headersChecksum != headersSum {
            throw ParsingError.envelopeAuthenticityFailure
        }
        Log.debug("Envelope checksum verified.") // TODO: remove

        // Verify checksum signature
        if  let signature = headersSignature,
            let authorSigningPublicKeyBase64 = authorProfile[.signingKey],
            let authorSigningPublicKey = Crypto.base64decode(authorSigningPublicKeyBase64) {
            guard try Crypto.verifySignature(publicKey: authorSigningPublicKey, signature: signature, originData: Array(headersSumBytes)) else {
                throw CryptoError.signatureMismatch
            }
            Log.debug("Envelope signature verified.") // TODO: remove
        }
    }

    public static func accessLinkGroup(link: String, accessKeyFingerprint: String, accessKeyEncrypted: [UInt8], encryptionKeyId: String) -> String {
        // TODO: use arrays to make this
        return "link=\(link); fingerprint=\(accessKeyFingerprint); value=\(Crypto.base64encode(accessKeyEncrypted)); id=\(encryptionKeyId)"

    }

    public static func parseHeaderAttributes(header: String) -> [String:String] {
        var result:[String:String] = [:]
        let attributes = header.split(separator: ";")
        for attribute in attributes {
            let kv = attribute.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=", maxSplits: 1)
            if kv.count != 2 {
                //throw ParsingError.badHeaderFormat
                Log.error("bad header format:", context: header)
                continue
            }
            let k = kv[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let v = String(kv[1].trimmingCharacters(in: .whitespacesAndNewlines))
            result[k] = v
        }
        return result
    }

    private mutating func parseAccessLink() throws {
        guard let authorProfile = authorProfile else {
            throw MessageError.missingAuthor
        }
        guard let accessLinks = accessLinks else {
            throw ParsingError.badAccessLinks
        }
        let readerLinks = accessLinks.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let connectionLink = localUser.connectionLinkFor(remoteAddress: authorProfile.address.address)

        for readerLink in readerLinks {
            let readerMap = Envelope.parseHeaderAttributes(header: readerLink)
            if let accessKeyFP = readerMap["fingerprint"],
               let value = readerMap["value"],
               let link = readerMap["link"],
               let _ = readerMap["id"],
               link == connectionLink {
                // The signing key is already verified on mail agent
                guard Crypto.publicKeyFingerprint(publicKey: localUser.publicSigningKey).hasPrefix(accessKeyFP) else {
                    throw CryptoError.fingerprintMismatch
                }
                // TODO: check if keyFP matches local FP?
                accessKey = try Crypto.decryptAnonymous(cipherText: value, privateKey: self.localUser.privateEncryptionKey, publicKey: self.localUser.publicEncryptionKey)
            }
        }
    }

    func dumpToFile(to: URL) throws {
        FileManager.default.createFile(atPath: to.path, contents: nil, attributes: nil)
        let envelopeTempFileHandle = try FileHandle(forWritingTo: to)
        try envelopeTempFileHandle.write(contentsOf: envelopeData)
        try envelopeTempFileHandle.close()
    }
}

public struct ContentHeaders {
    // TODO: Optional properties are not ideal. We should find another way initialize instances, e.g. with a static factory method.

    let messageID: String
    let date: Date
    let subject: String
    let subjectId: String
    let parentId: String?

    let files: [MessageFileInfo]?   // Grouped
    let filesHeader: String?        // Raw
    let fileParts: [MessageFilePartInfo]?

    let category: MessageCategory
    let size: UInt64
    let checksum: String
    let authorAddress: EmailAddress
    let readersAddresses: [EmailAddress]?

    let contentHeadersText: String

    init(
        messageID: String,
        date: Date,
        subject: String,
        subjectID: String,
        parentID: String? = nil,    // Indicator if it is a child or root
        filesHeader: String? = nil,
        files: [MessageFileInfo]? = nil,
        fileParts: [MessageFilePartInfo]? = nil,
        checksum: String,
        category: MessageCategory = .personal,
        size: UInt64,
        authorAddress: EmailAddress,
        readersAddresses: [EmailAddress]? = nil
    ) throws {
        self.messageID = messageID
        self.date = date
        self.subject = subject
        self.subjectId = subjectID
        self.parentId = parentID
        self.files = files
        self.checksum = checksum
        self.category = category
        self.size = size
        self.authorAddress = authorAddress
        self.readersAddresses = readersAddresses

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC") // ALWAYS UTC!

        var serializedHeaders: [[String]] = []
        serializedHeaders.append([HEADER_CONTENT_MESSAGE_ID, messageID])
        serializedHeaders.append([HEADER_CONTENT_AUTHOR, authorAddress.address])
        serializedHeaders.append([HEADER_CONTENT_SIZE, String(size)])
        serializedHeaders.append([HEADER_CONTENT_CHECKSUM, "algorithm=\(Crypto.CHECKSUM_ALGORITHM); value=\(checksum)"])
        serializedHeaders.append([HEADER_CONTENT_CATEGORY, category.rawValue])
        serializedHeaders.append([HEADER_CONTENT_DATE, dateFormatter.string(from: date)])
        serializedHeaders.append([HEADER_CONTENT_SUBJECT, subject])
        serializedHeaders.append([HEADER_CONTENT_SUBJECT_ID, subjectID])
        
        // Broadcast messages do not have readers
        if let readersAddresses = self.readersAddresses,
           !readersAddresses.isEmpty {
            serializedHeaders.append([HEADER_CONTENT_READERS, readersAddresses.map({ $0.address }).joined(separator: ", ")])
        }

        if let filesHeader {
            self.filesHeader = filesHeader
            let (parts, _) = parseFilesHeader(filesHeader)
            self.fileParts = parts
            serializedHeaders.append([HEADER_CONTENT_FILES, filesHeader])
        } else if let fileParts, !fileParts.isEmpty {
            self.fileParts = fileParts
            let fHeader = fileParts.map { serializeMessageFileInfo($0) }.joined(separator: ", ")
            self.filesHeader = fHeader
            serializedHeaders.append([HEADER_CONTENT_FILES, fHeader])
        } else {
            self.fileParts = nil
            self.filesHeader = nil
        }

        if let parentID = parentID,
            messageID != parentID {
            serializedHeaders.append([HEADER_CONTENT_PARENT_ID, parentID])
        }
        self.contentHeadersText = serializedHeaders.map({ $0.joined(separator: ": ") }).joined(separator: "\n")
    }

    func dumpToFile(to: URL) throws {
        FileManager.default.createFile(atPath: to.path, contents: nil, attributes: nil)
        let headersTempFileHandle = try FileHandle(forWritingTo: to)
        try headersTempFileHandle.write(contentsOf: contentHeadersText.bytes)
        try headersTempFileHandle.close()
    }
}


public func contentFromHeaders(headersText: String) throws -> ContentHeaders {
    var parsedMessageID: String?
    var parsedAuthorAddress: EmailAddress?
    var parsedDate: Date?
    var parsedSize: UInt64?
    var parsedChecksum: String?
    var parsedSubject: String?
    var parsedSubjectID: String?
    var parsedParentID: String?
    var parsedCategory: MessageCategory = .personal
    var parsedReadersAddresses: [EmailAddress] = []
    var parsedFilesHeader: String?
    var parsedFileParts: [MessageFilePartInfo] = []
    var parsedFiles: [MessageFileInfo] = []

    for header in headersText.split(separator: "\n").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
        let headerParts = header.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if headerParts.count == 1 {
            // Empty headers are ignored
            continue
        }
        guard headerParts.count == 2 else {
            throw ParsingError.badHeaderFormat
        }

        switch headerParts[0].lowercased() {
        case HEADER_CONTENT_MESSAGE_ID:
            parsedMessageID = headerParts[1]

        case HEADER_CONTENT_AUTHOR:
            if let authorAddress = EmailAddress(headerParts[1]) {
                parsedAuthorAddress = authorAddress
            }

        case HEADER_CONTENT_DATE:
            if let date = parseISO8601Date(headerParts[1]) {
                parsedDate = date
            } else {
                parsedDate = .distantPast
            }


        case HEADER_CONTENT_SIZE:
            if let size = UInt64(headerParts[1]) {
                parsedSize = size
            } else {
                throw ParsingError.badPayloadSize
            }

        case HEADER_CONTENT_CHECKSUM:
            let checksumMap = Envelope.parseHeaderAttributes(header: headerParts[1])
            if let algorithm = checksumMap["algorithm"],
               let sum = checksumMap["value"] {
                if algorithm.lowercased() != Crypto.CHECKSUM_ALGORITHM {
                    throw CryptoError.algorithmMismatch
                }
                parsedChecksum = sum
            }

        case HEADER_CONTENT_SUBJECT:
            parsedSubject = headerParts[1]

        case HEADER_CONTENT_SUBJECT_ID:
            parsedSubjectID = headerParts[1]

        case HEADER_CONTENT_PARENT_ID:
            parsedParentID = headerParts[1]

        case HEADER_CONTENT_FILES:
            parsedFilesHeader = headerParts[1]
            (parsedFileParts, parsedFiles) = parseFilesHeader(headerParts[1])

        case HEADER_CONTENT_CATEGORY:
            if let category = MessageCategory(rawValue: headerParts[1]) {
                parsedCategory = category
            }

        case HEADER_CONTENT_READERS:
            let addresses = headerParts[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            for address in addresses {
                guard let address = EmailAddress(address) else {
                    throw ParsingError.badReaderAddress
                }
                parsedReadersAddresses.append(address)
            }
        default:
            Log.warning("unknown content header encountered", context: headerParts[1])
        }

        // SubjectID can be empty, in which case it is identical to the MessageID
        // in parent messages or ParentID in file messages.
        if parsedSubjectID == nil {
            parsedSubjectID = parsedParentID ?? parsedMessageID
        }
    }

    guard let parsedMessageID,
       let parsedDate,
       let parsedSubject,
       let parsedSubjectID,
       let parsedChecksum,
       let parsedSize,
       let parsedAuthorAddress else {
        throw ParsingError.badContentHeaders
    }

    return try ContentHeaders(messageID: parsedMessageID,
                date: parsedDate,
                subject: parsedSubject,
                subjectID: parsedSubjectID,
                parentID: parsedParentID,
                filesHeader: parsedFilesHeader,
                files: parsedFiles,
                fileParts: parsedFileParts,
                checksum: parsedChecksum,
                category: parsedCategory,
                size: parsedSize,
                authorAddress: parsedAuthorAddress,
                readersAddresses: parsedReadersAddresses)
}

public func parseFilesHeader(_ filesHeader: String) -> ([MessageFilePartInfo], [MessageFileInfo]) {
    let fileStrings = filesHeader.split(separator: ",")
    var fileParts: [MessageFilePartInfo] = []

    for fileString in fileStrings {
        var urlInfoDict = [String: String]()
        var messageId: String? = nil
        var part: UInt64 = 0
        var totalParts: UInt64 = 0
        var modifiedAt: Date = Date()

        let keyValuePairs = fileString.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        for pair in keyValuePairs {
            let keyValue = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
            guard keyValue.count == 2 else { continue }
            let key = keyValue[0]
            let value = keyValue[1]

            switch key {
            case "name":
                urlInfoDict["name"] = value
            case "type":
                urlInfoDict["type"] = value
            case "size":
                urlInfoDict["size"] = value
            case "id":
                messageId = value
            case "part":
                let parts = value.split(separator: "/").compactMap { UInt64($0) }
                if parts.count == 2 {
                    if parts[0] > 0 {
                        part = parts[0] - 1
                    }
                    totalParts = parts[1]
                }
            case "modified":
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: value) {
                    modifiedAt = date
                }

            default:
                break
            }
        }

        if
            let messageId,
            let name = urlInfoDict["name"]?.removingPercentEncoding,
            let mimeType = urlInfoDict["type"],
            let sizeString = urlInfoDict["size"],
            let size = UInt64(sizeString)
        {
            let urlInfo = URLInfo(url: nil, name: name, mimeType: mimeType, size: size, modifedAt: modifiedAt)
            let fileInfo = MessageFilePartInfo(urlInfo: urlInfo, messageId: messageId, part: part, size: part, totalParts: totalParts)
            fileParts.append(fileInfo)
        }
    }

    let fileInfos: [MessageFileInfo] = groupMessageFilePartsIntoFileInfo(parts: fileParts)
    return (fileParts, fileInfos)
}

private func serializeMessageFileInfo(_ info: MessageFilePartInfo, isRootInfo: Bool = true) -> String {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: "UTC")
    return ["name=\(info.urlInfo.name)",
            "type=\(info.urlInfo.mimeType)",
            "modified=\(dateFormatter.string(from: info.urlInfo.modifedAt))",
            "size=\(info.urlInfo.size)",
            "id=\(info.messageId)",
            "part=\(info.part)/\(info.totalParts)"].joined(separator: ";")
}


private func groupMessageFilePartsIntoFileInfo(parts: [MessageFilePartInfo]) -> [MessageFileInfo] {
    var partsDictionary: [String: [MessageFilePartInfo]] = [:]

    for part in parts {
        // Group on name
        let name = part.urlInfo.name
        if partsDictionary[name] == nil {
            partsDictionary[name] = [part]
        } else {
            partsDictionary[name]?.append(part)
        }
    }

    var fileInfoArray: [MessageFileInfo] = []
    for (_, groupedParts) in partsDictionary {
        let sortedParts = groupedParts.sorted { $0.part < $1.part }
        let firstPart = sortedParts.first!
        let complete = sortedParts.count == firstPart.totalParts
        let messageIdsParts = sortedParts.map { $0.messageId }

        let fileInfo = MessageFileInfo(
            name: firstPart.urlInfo.name,
            mimeType: firstPart.urlInfo.mimeType,
            size: firstPart.urlInfo.size,
            modifedAt: firstPart.urlInfo.modifedAt,
            messageIds: messageIdsParts,
            complete: complete
        )
        fileInfoArray.append(fileInfo)
    }

    return fileInfoArray
}

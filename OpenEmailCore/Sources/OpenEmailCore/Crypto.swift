import Foundation
import Sodium
import CryptoKit
import CommonCrypto
import Logging

// MARK: - PayloadSeal

struct PayloadSeal {
    var algorithm: String = ""
    var stream: Bool = false
    var chunkSize: Int = 0
    var originalHeaderValue: String = ""
}

let CHUNK_SIZE_KEY = "chunk-size"
let MAX_CHUNK_SIZE: Int = 1048576
let DEFAULT_CHUNK_SIZE: Int = 8192
let MIN_CHUNK_SIZE: Int = 1024

extension PayloadSeal {
    func toHeader() -> String {
        if stream {
            if algorithm.isEmpty || chunkSize == 0 {
                return ""
            }
            return "algorithm=\(algorithm); \(CHUNK_SIZE_KEY)=\(chunkSize)"
        }
        return "algorithm=\(algorithm)"
    }
}

func cipherInfoFromHeader(headerValue: String) throws -> PayloadSeal {
    var ci = PayloadSeal(
        algorithm: "",
        stream: false,
        chunkSize: 0,
        originalHeaderValue: headerValue
    )
    let attributes = Envelope.parseHeaderAttributes(header: headerValue)
    if let algorithm = attributes["algorithm"] {
        if let chunkSizeStr = attributes["chunk-size"],
           let chunkSize = Int(chunkSizeStr),
           algorithm == Crypto.SYMMETRIC_FILE_CIPHER {
            if chunkSize < MIN_CHUNK_SIZE || chunkSize >= MAX_CHUNK_SIZE {
                throw CryptoError.badChunkSizeError
            }
            ci.stream = true
            ci.chunkSize = chunkSize
        }
    }
    return ci
}

// MARK: - Crypto

class Crypto {
    public static let ANONYMOUS_ENCRYPTION_CIPHER = "curve25519xsalsa20poly1305"
    public static let CHECKSUM_ALGORITHM = "sha256"
    public static let SIGNING_ALGORITHM = "ed25519"
    public static let SYMMETRIC_CIPHER = "xchacha20poly1305"
    public static let SYMMETRIC_FILE_CIPHER = "secretstream_xchacha20poly1305"
    public static let SYMMETRIC_FILE_CIPHER_HEADER_SIZE = 24
    public static let SYMMETRIC_FILE_CIPHER_OVERHEAD_SIZE = 17
    private static let FIELD_SEPARATOR = "$"

    private init() {}

    static func base64encode(_ data: [UInt8]) -> String {
        let sodium = Sodium()
        return sodium.utils.bin2base64(data, variant: .ORIGINAL)!
    }

    static func base64decode(_ encodedData: String) -> [UInt8]? {
        let sodium = Sodium()
        return sodium.utils.base642bin(encodedData, variant: .ORIGINAL, ignore: " \n")
    }

    static func generateEncryptionKeys() -> (privateKey: String, publicKey: String, keyId: String) {
        let sodium = Sodium()
        let keyPair = sodium.box.keyPair()!
        let encodedPrivateKey = base64encode(keyPair.secretKey)
        let encodedPublicKey = base64encode(keyPair.publicKey)
        let keyId = generateRandomString(length: 4)
        return (encodedPrivateKey, encodedPublicKey, keyId)
    }

    static func generateSigningKeys() -> (privateKey: String, publicKey: String) {
        let sodium = Sodium()
        let keyPair = sodium.sign.keyPair()!
        let encodedPrivateKey = base64encode(keyPair.secretKey)
        let encodedPublicKey = base64encode(keyPair.publicKey)
        return (encodedPrivateKey, encodedPublicKey)
    }

    static func signData(publicKey: [UInt8], privateKey: [UInt8], data: Data) throws -> String {
        let sodium = Sodium()
        guard let signature = sodium.sign.signature(message: Array(data), secretKey: privateKey) else {
            throw CryptoError.signatureMismatch
        }
        let encodedSignature = base64encode(signature)
        return encodedSignature
    }

    static func verifySignature(publicKey: [UInt8], signature: String, originData: [UInt8]) throws -> Bool {
        if let signedMessage = base64decode(signature) {
            let sodium = Sodium()
            return sodium.sign.verify(message: originData, publicKey: publicKey, signature: signedMessage)
        }
        return false
    }

    static func publicKeyFingerprint(publicKey: [UInt8]) -> String {
        let (fp, _) = sha256sum(publicKey)
        return fp
    }

    
    static func generateRandomBytes(length: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard status == errSecSuccess else {
            throw CryptoError.randomGeneratorFailure
        }
        return bytes
    }

    static func generateRandomString(length: Int) -> String {
        let letters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        var randomString = ""

        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<letters.count)
            let character = letters[letters.index(letters.startIndex, offsetBy: randomIndex)]
            randomString.append(character)
        }

        return randomString
    }

    static func generateRandomToken(tokenLength: Int) -> String {
        return generateRandomString(length: tokenLength)
    }

    static func encryptAnonymous(data: [UInt8], publicKey: [UInt8]) throws -> [UInt8] {
        let sodium = Sodium()
        guard let encryptedData = sodium.box.seal(message: data, recipientPublicKey: publicKey) else {
            throw CryptoError.encryptionError
        }
        return encryptedData
    }

    static func decryptAnonymous(cipherText: String, privateKey: [UInt8], publicKey: [UInt8]) throws -> [UInt8] {
        let sodium = Sodium()
        guard let data = base64decode(cipherText) else {
            throw CryptoError.badCipherText
        }
        guard let decrypted = sodium.box.open(anonymousCipherText: data, recipientPublicKey: publicKey, recipientSecretKey: privateKey) else {
            throw CryptoError.badCipherText
        }
        return decrypted
    }

    static func encryptFile_secretStream(inputURL: URL, outputURL: URL, secretkey: [UInt8]) throws {
        let sodium = Sodium()
        let stream_enc = sodium.secretStream.xchacha20poly1305.initPush(secretKey: secretkey)!
        let header = stream_enc.header()
        let blockSize = 4096

        var inputBuffer = [UInt8](repeating: 0, count: blockSize)

        guard let inputStream = InputStream(url: inputURL), let outputStream = OutputStream(url: outputURL, append: false) else {
            throw CryptoError.encryptionError
        }

        inputStream.open()
        outputStream.open()
        outputStream.write(header, maxLength: header.count)

        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&inputBuffer, maxLength: blockSize)
            if bytesRead < 0 {
                throw CryptoError.encryptionError
            }
            if bytesRead == 0 {
                break
            }

            guard let outputBuffer = stream_enc.push(message: Array(inputBuffer.prefix(bytesRead)), tag: inputStream.hasBytesAvailable ? .MESSAGE : .FINAL) else {
                throw CryptoError.encryptionError
            }

            let bytesEncrypted = outputBuffer.count
            let bytesWritten = outputStream.write(outputBuffer, maxLength: bytesEncrypted)
            if bytesWritten != bytesEncrypted {
                throw CryptoError.encryptionError
            }
        }

        inputStream.close()
        outputStream.close()
    }

    static func decryptFile_secretStream(inputURL: URL, outputURL: URL, secretkey: [UInt8]) throws {
        let sodium = Sodium()

        let blockSize = 4113
        var header = [UInt8](repeating: 0, count: 24)
        var inputBuffer = [UInt8](repeating: 0, count: blockSize)

        guard let inputStream = InputStream(url: inputURL), let outputStream = OutputStream(url: outputURL, append: false) else {
            throw CryptoError.ioError
        }

        inputStream.open()
        outputStream.open()

        inputStream.read(&header, maxLength: 24)
        let stream_dec = sodium.secretStream.xchacha20poly1305.initPull(secretKey: secretkey, header: header)!

        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&inputBuffer, maxLength: blockSize)
            if bytesRead < 0 {
                throw CryptoError.ioError
            }

            if bytesRead == 0 {
                break
            }
            guard let (outputBuffer, tag) = stream_dec.pull(cipherText: Array(inputBuffer.prefix(bytesRead))) else {
                throw CryptoError.ioError
            }

            if tag == .MESSAGE {
                let bytesDecrypted = outputBuffer.count
                let bytesWritten = outputStream.write(outputBuffer, maxLength: bytesDecrypted)
                if bytesWritten != bytesDecrypted {
                    throw CryptoError.ioError
                }
            }
            if tag == .FINAL {
                break
            }
        }
        inputStream.close()
        outputStream.close()
    }

    static func decryptFile_xchacha20poly1305(inputURL: URL, outputURL: URL, secretkey: [UInt8]) throws {
        let cipherData = try Data(contentsOf: inputURL)
        let decryptedData = try decrypt_xchacha20poly1305(cipherData: Array(cipherData), secretKey: secretkey)
        try Data(decryptedData).write(to: outputURL)
    }

    static func encryptFile_xchacha20poly1305(inputURL: URL, outputURL: URL, secretkey: [UInt8]) throws {
        let plaintextData = try Data(contentsOf: inputURL)
        let encryptedData = try encrypt_xchacha20poly1305(plainText: Array(plaintextData), secretKey: secretkey)
        try Data(encryptedData).write(to: outputURL)
    }

    static func encryptFilePart_xchacha20poly1305(inputURL: URL,  secretkey: [UInt8], bytesCount: UInt64? = nil, offset: UInt64? = nil) throws -> (Data, [UInt8]) {
        let fileHandle: FileHandle
        let isSecurityScoped = inputURL.startAccessingSecurityScopedResource()

        do {
            fileHandle = try FileHandle(forReadingFrom: inputURL)
        } catch {
            throw CryptoError.fileReadError
        }
        defer {
            if isSecurityScoped {
                inputURL.stopAccessingSecurityScopedResource()
            }
            fileHandle.closeFile()
        }

        if let offset = offset {
            // Seek to the offset in the file before reading
            do {
                try fileHandle.seek(toOffset: offset)
            } catch {
                throw CryptoError.fileReadError
            }
        }

        let dataToEncrypt: Data
        if let bytesCount = bytesCount {
            // Read the specified number of bytes from the file
            dataToEncrypt = fileHandle.readData(ofLength: Int(bytesCount))
        } else {
            // Read to the end of the file from the offset
            dataToEncrypt = fileHandle.readDataToEndOfFile()
        }

        // Write the encrypted data to the output URL
        let encryptedBytes = try encrypt_xchacha20poly1305(plainText: Array(dataToEncrypt), secretKey: secretkey)
        return (dataToEncrypt, encryptedBytes)
    }

    static func readFilePart(inputURL: URL, bytesCount: UInt64? = nil, offset: UInt64? = nil) throws -> Data {
        let fileHandle: FileHandle
        let isSecurityScoped = inputURL.startAccessingSecurityScopedResource()

        do {
            fileHandle = try FileHandle(forReadingFrom: inputURL)
        } catch {
            throw CryptoError.fileReadError
        }
        defer {
            if isSecurityScoped {
                inputURL.stopAccessingSecurityScopedResource()
            }
            fileHandle.closeFile()
        }

        if let offset = offset {
            // Seek to the offset in the file before reading
            do {
                try fileHandle.seek(toOffset: offset)
            } catch {
                throw CryptoError.fileReadError
            }
        }

        let dataRead: Data
        if let bytesCount = bytesCount {
            // Read the specified number of bytes from the file
            dataRead = fileHandle.readData(ofLength: Int(bytesCount))
        } else {
            // Read to the end of the file from the offset
            dataRead = fileHandle.readDataToEndOfFile()
        }

        return dataRead
    }

    static func encrypt_xchacha20poly1305(plainText: [UInt8], secretKey: [UInt8]) throws -> [UInt8] {
        let sodium = Sodium()
        guard let encrypted:[UInt8] = sodium.aead.xchacha20poly1305ietf.encrypt(message: plainText, secretKey: secretKey) else {
            throw CryptoError.encryptionError
        }
        return encrypted
    }

    static func decrypt_xchacha20poly1305(cipherData: [UInt8], secretKey: [UInt8]) throws -> [UInt8]{
        let sodium = Sodium()

        guard let decrypted = sodium.aead.xchacha20poly1305ietf.decrypt(nonceAndAuthenticatedCipherText: cipherData, secretKey: secretKey) else {
            throw CryptoError.decryptionError
        }
        return decrypted
    }

    static func sha256sum(_ content: [UInt8]) -> (String, Data) {
        let digest = CryptoKit.SHA256.hash(data: Data(content))
        return (digest.compactMap { String(format: "%02x", $0) }.joined(), Data(digest))
    }

    static func sha256sum(_ content: Data) -> (String, Data) {
        let digest = CryptoKit.SHA256.hash(data: content)
        return (digest.compactMap { String(format: "%02x", $0) }.joined(), Data(digest))
    }

    static func sha256fileSum(fileAtURL url: URL, fromOffset: UInt64, bytesCount: Int = 0) throws -> (String, Data, Int64) {
        let file: FileHandle
        let isSecurityScoped = url.startAccessingSecurityScopedResource()

        do {
            file = try FileHandle(forReadingFrom: url)
        } catch {
            Log.error("Error while reading file: \(error)")
            throw CryptoError.ioError
        }

        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
            file.closeFile()
        }

        let bufferSize = 1024 * 1024
        var context = SHA256()
        var processedBytes: UInt64 = 0

        // Seek to the specified offset
        file.seek(toFileOffset: fromOffset)

        while autoreleasepool(invoking: {
            // Calculate the number of bytes to read, not exceeding the remaining bytes
            var bytesToRead: UInt64 = UInt64(bufferSize)
            if bytesCount > 0 {
                let remainingBytes = UInt64(bytesCount) - processedBytes
                bytesToRead = min(bytesToRead, remainingBytes)
            }

            if bytesToRead > 0 {
                let data = file.readData(ofLength: Int(bytesToRead))
                processedBytes += UInt64(data.count)
                context.update(data: data)
                return processedBytes < bytesCount
            } else {
                return false
            }
        }) {}

        let digest = context.finalize()
        return (digest.map { String(format: "%02x", $0) }.joined(), Data(digest), Int64(processedBytes))
    }

    static func fileChecksum(url: URL, fromOffset: UInt64 = 0, bytesCount: UInt64 = 0) throws -> (String, Data) {
        let (checksumHex, checksumBytes, _) = try sha256fileSum(fileAtURL: url, fromOffset: fromOffset, bytesCount: Int(bytesCount))
        return (checksumHex, checksumBytes)
    }

    static func checksum(data: Data) -> (String, Data) {
        return sha256sum(data)
    }

    static func checksum(digest: CryptoKit.SHA256.Digest) -> (String, Data) {
        return (digest.compactMap { String(format: "%02x", $0) }.joined(), Data(digest))
    }
}

// MARK: - Crypto Errors

enum CryptoError: Error {
    case ioError
    case badAccessKey
    case encryptionError
    case decryptionError
    case encodingError
    case badCipherText
    case incompatibleCipherText
    case fingerprintMismatch
    case keyGenerationError
    case badChunkSizeError
    case checksumMissing
    case checksumMismatched
    case checksumIncomplete
    case contentChecksumMismatched
    case algorithmMismatch
    case signatureMismatch
    case randomGeneratorFailure
    case cipherInfoMissing
    case signingKeyMissing
    case fileReadError
}

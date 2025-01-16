import Foundation
import Sodium
import CommonCrypto

public enum UserError: Error {
    case invalidEmailAddress
    case invalidKey
    case invalidProfileURL
    case invalidProfile
    case profileReadError
    case profileNotFound
    case profileNotSynced
    case invalidLink
    case emailV2notSupported
}

public protocol User {
    var address: EmailAddress { get }
}

public struct LocalUser: User {
    public let address: EmailAddress
    public let name: String?

    public var privateEncryptionKey: [UInt8]
    public var privateEncryptionKeyBase64: String

    public let publicEncryptionKey: [UInt8]
    public let publicEncryptionKeyBase64: String
    public let publicEncryptionKeyId: String

    public var privateSigningKey: [UInt8]
    public var privateSigningKeyBase64: String

    public let publicSigningKey: [UInt8]
    public let publicSigningKeyBase64: String
    public let publicSigningKeyFingerprint: String

    public init(
        address: String,
        name: String? = "(No name)",
        privateEncryptionKeyBase64: String,
        publicEncryptionKeyBase64: String,
        publicEncryptionKeyId: String,
        privateSigningKeyBase64: String,
        publicSigningKeyBase64: String
    ) throws {
        let sodium = Sodium()
        guard
            let privateEncryptionKey = sodium.utils.base642bin(privateEncryptionKeyBase64, variant: .ORIGINAL),
            let publicEncryptionKey = sodium.utils.base642bin(publicEncryptionKeyBase64, variant: .ORIGINAL),
            let privateSigningKey = sodium.utils.base642bin(privateSigningKeyBase64, variant: .ORIGINAL),
            let publicSigningKey = sodium.utils.base642bin(publicSigningKeyBase64, variant: .ORIGINAL)
        else {
            throw UserError.invalidKey
        }

        guard let address = EmailAddress(address) else {
            throw UserError.invalidEmailAddress
        }

        self.privateEncryptionKey = privateEncryptionKey
        self.privateEncryptionKeyBase64 = privateEncryptionKeyBase64
        self.publicEncryptionKey = publicEncryptionKey
        self.publicEncryptionKeyBase64 = publicEncryptionKeyBase64
        self.publicEncryptionKeyId = publicEncryptionKeyId

        self.privateSigningKey = privateSigningKey
        self.privateSigningKeyBase64 = privateSigningKeyBase64
        self.publicSigningKey = publicSigningKey
        self.publicSigningKeyBase64 = publicSigningKeyBase64
        self.publicSigningKeyFingerprint = Crypto.publicKeyFingerprint(publicKey: publicSigningKey)

        self.address = address
        self.name = name
    }

    public func connectionLinkFor(remoteAddress: String) -> String {
        let linkJoin = [self.address.address, remoteAddress]
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .sorted()
            .joined()
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(linkJoin, CC_LONG(linkJoin.count), &digest)
        return Data(digest).map { String(format: "%02hhx", $0) }.joined()
    }
}

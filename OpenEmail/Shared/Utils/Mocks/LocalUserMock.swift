import Foundation
import OpenEmailCore

extension LocalUser {
    static func makeRandom() throws -> LocalUser {
        return try LocalUser(
            address: "john.doe@gmail.com",
            privateEncryptionKeyBase64: "privateEncKey",
            publicEncryptionKeyBase64: "publicEncKey",
            publicEncryptionKeyId: "0001",
            privateSigningKeyBase64: "privateSigKey",
            publicSigningKeyBase64: "publicSigKey"
        )
    }
}

import Foundation

public extension LocalUser {
    private static var internalCurrentUser: LocalUser?

    static var current: LocalUser? {
        guard UserDefaults.standard.registeredEmailAddress != nil else {
            // Return nil if there is no user logged in
            internalCurrentUser = nil
            return nil
        }

        if let internalCurrentUser {
            // return the cached user
            return internalCurrentUser
        } else {
            // no cached user yet: update cached instance and return it
            update()
            return internalCurrentUser
        }
    }

    static func update() {
        let keysStore = standardKeyStore()

        guard
            let address = UserDefaults.standard.registeredEmailAddress,
            let privateKeys = try? keysStore.getKeys(),
            let publicSigningKeyN = UserDefaults.standard.publicSigningKey,
            let publicEncryptionKeyN = UserDefaults.standard.publicEncryptionKey,
            let publicEncryptionKeyId = UserDefaults.standard.publicEncryptionKeyId
        else {
            internalCurrentUser = nil
            return
        }

        internalCurrentUser = try? LocalUser(
            address: address,
            privateEncryptionKeyBase64: privateKeys.privateEncryptionKey,
            publicEncryptionKeyBase64: publicEncryptionKeyN,
            publicEncryptionKeyId: publicEncryptionKeyId,
            privateSigningKeyBase64: privateKeys.privateSigningKey,
            publicSigningKeyBase64: publicSigningKeyN
        )
    }
}

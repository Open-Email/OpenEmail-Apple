import Foundation
import KeychainAccess
import Utils

public enum KeychainStoreError: Error {
    case unexpectedStatus(OSStatus)
}

public protocol KeysStoring {
    func storeKeys(_ keys: PrivateKeys) throws
    func getKeys() throws -> PrivateKeys?
    func deleteKeys() throws
}

public struct PrivateKeys: Codable {
    public var privateEncryptionKey: String = ""
    public var privateSigningKey: String = ""

    public init(privateEncryptionKey: String, privateSigningKey: String) {
        self.privateEncryptionKey = privateEncryptionKey
        self.privateSigningKey = privateSigningKey
    }
}

public func standardKeyStore() -> KeysStoring {
    #if DEBUG
    if UserDefaults.standard.useKeychainStore {
        return SecureKeysStore.shared
    } else {
        return UserDefaultsKeysStore.shared
    }
    #else
    return SecureKeysStore.shared
    #endif
}

final class SecureKeysStore: KeysStoring {
    static let shared = SecureKeysStore()
    private static let key = "privateKeys"

    private let keychain: Keychain

    private init() {
        keychain = Keychain(service: "openemail.keys")
    }

    func storeKeys(_ keys: PrivateKeys) throws {
        guard !isPreview else { return }
        let data = try JSONEncoder().encode(keys)
        try keychain.set(data, key: Self.key)
    }

    func getKeys() throws -> PrivateKeys? {
        guard !isPreview else { return nil }
        if
            let keysData = try keychain.getData(Self.key),
            let keys = try? JSONDecoder().decode(PrivateKeys.self, from: keysData)
        {
            return keys
        }
        return nil
    }

    func deleteKeys() throws {
        guard !isPreview else { return }
        try keychain.remove(Self.key)
    }
}

#if DEBUG
final class UserDefaultsKeysStore: KeysStoring {
    static let shared = UserDefaultsKeysStore()
    private static let key = "privateKeys"

    private let defaults = UserDefaults.standard

    func storeKeys(_ keys: PrivateKeys) throws {
        guard !isPreview else { return }
        let data = try JSONEncoder().encode(keys)
        defaults.set(data, forKey: Self.key)
    }

    func getKeys() throws -> PrivateKeys? {
        guard !isPreview else { return nil }

        if
            let keysData = defaults.data(forKey: Self.key),
            let keys = try? JSONDecoder().decode(PrivateKeys.self, from: keysData)
        {
            return keys
        }
        return nil
    }

    func deleteKeys() throws {
        guard !isPreview else { return }
        defaults.removeObject(forKey: Self.key)
    }
}
#endif

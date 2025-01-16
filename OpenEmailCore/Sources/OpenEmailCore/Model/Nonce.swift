import Foundation

struct Nonce {
    private let localUser: LocalUser

    private enum Constants {
        static let tokenLength = 32
        static let headerFieldSeparator = "; "
        static let headerKeyValueSeparator = "="
        static let NONCE_SCHEME = "SOTN"
        static let NONCE_HEADER_VALUE_HOST = "host"
        static let NONCE_HEADER_VALUE_KEY = "value"
        static let NONCE_HEADER_ALGORITHM_KEY = "algorithm"
        static let NONCE_HEADER_SIGNATURE_KEY = "signature"
        static let NONCE_HEADER_PUBKEY_KEY = "key"
    }

    init(localUser: LocalUser) {
        self.localUser = localUser
    }

    func sign(host: String) throws -> String {
        let value = Crypto.generateRandomToken(tokenLength: Constants.tokenLength)
        let signature = try Crypto.signData(publicKey: localUser.publicSigningKey, privateKey: localUser.privateSigningKey, data: Data((host + value).bytes))

        var kvPairs: [String] = []

        kvPairs.append([Constants.NONCE_HEADER_VALUE_KEY, value].joined(separator: Constants.headerKeyValueSeparator))
        kvPairs.append([Constants.NONCE_HEADER_VALUE_HOST, host].joined(separator: Constants.headerKeyValueSeparator))
        kvPairs.append([Constants.NONCE_HEADER_ALGORITHM_KEY, Crypto.SIGNING_ALGORITHM].joined(separator: Constants.headerKeyValueSeparator))
        kvPairs.append([Constants.NONCE_HEADER_SIGNATURE_KEY, signature].joined(separator: Constants.headerKeyValueSeparator))
        kvPairs.append([Constants.NONCE_HEADER_PUBKEY_KEY, localUser.publicSigningKeyBase64].joined(separator: Constants.headerKeyValueSeparator))
        return Constants.NONCE_SCHEME + " " + kvPairs.joined(separator: Constants.headerFieldSeparator)
    }
}

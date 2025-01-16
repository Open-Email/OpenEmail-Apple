import Foundation
import Observation
import OpenEmailCore
import Logging

@Observable
class OnboardingExistingAccountViewModel {
    var privateEncryptionKey: String = ""
    var privateSigningKey: String = ""
    var isAuthorizing = false
    var alertConfiguration: AlertConfiguration?

    var hasBothKeys: Bool {
        !privateEncryptionKey.isEmpty && !privateSigningKey.isEmpty
    }

    @ObservationIgnored
    @Injected(\.client) private var client

    private let keyStore = standardKeyStore()

    func authenticate(emailAddress: String) async {
        isAuthorizing = true

        defer { isAuthorizing = false }
        privateEncryptionKey = privateEncryptionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        privateSigningKey = privateSigningKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let address = EmailAddress(emailAddress) else {
            alertConfiguration = AlertConfiguration(title: "The provided email address is invalid.", message: nil)
            return
        }

        do {
            let (localUser, failedHosts) = try await client.authenticate(
                emailAddress: address,
                privateEncryptionKey: privateEncryptionKey,
                privateSigningKey: privateSigningKey
            )

            guard let localUser else {
                alertConfiguration = AlertConfiguration(title: "The provided keys are invalid.", message: nil)
                return
            }

            if failedHosts.count > 0 {
                // At least one host which is configured for email is not authenticating or failing.
                // TODO: show some warning, but allow to proceed
                Log.error("some hosts failed", context: failedHosts)
            }

            try keyStore.storeKeys(.init(
                privateEncryptionKey: privateEncryptionKey,
                privateSigningKey: privateSigningKey
            ))

            let defaults = UserDefaults.standard
            defaults.publicEncryptionKey = localUser.publicEncryptionKeyBase64
            defaults.publicEncryptionKeyId = localUser.publicEncryptionKeyId
            defaults.publicSigningKey = localUser.publicSigningKeyBase64
            defaults.profileName = localUser.name

            // Email must be last!
            defaults.registeredEmailAddress = emailAddress
        } catch {
            Log.error("Could not store keys.", context: error)
            alertConfiguration = .alertConfiguration(for: error)
        }
    }
}

private extension AlertConfiguration {
    static func alertConfiguration(for error: Error) -> AlertConfiguration {
        var title: String?
        var message: String?

        if let keychainError = error as? KeychainStoreError {
            switch keychainError {
            case .unexpectedStatus(let status):
                title = "Could not store keys"
                message = "Keychain status: \(status)"
            }
        }

        return AlertConfiguration(
            title: title ?? "Something went wrong.",
            message: message ?? error.localizedDescription
        )
    }
}

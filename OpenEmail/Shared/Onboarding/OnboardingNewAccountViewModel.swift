import Foundation
import Observation
import OpenEmailCore
import Combine
import SwiftUI
import Logging

@Observable
class OnboardingNewAccountViewModel {
    private static let minimumNameLength = 1
    private static let initialContactAddresses = [
        "support@open.email"
    ]

    enum RegistrationStatus {
        case idle
        case generatingKeys
        case registeringAccount

        var statusText: String {
            switch self {
            case .idle: return ""
            case .generatingKeys: return "Generating keys…"
            case .registeringAccount: return "Registering account…"
            }
        }
    }

    struct EmailAvailabilityMessage: Equatable {
        var imageName: String = ""
        var text: String = ""
        var color: Color = .primary
    }

    let availableDomains = [
//        "email-v2.org",
        "open.email"
    ]

    @ObservationIgnored
    @Injected(\.client) private var client

    let keyStore = standardKeyStore()

    var localPart: String = "" {
        didSet {
            emailAvailabilityCheckSubject.send(())
        }
    }

    var fullName: String = ""
    var selectedDomainIndex = 0
    var alertConfiguration: AlertConfiguration?
    var registrationStatus: RegistrationStatus = .idle
    var isEmailAvailable: Bool?
    var emailAvailabilityMessage = EmailAvailabilityMessage()

    private var emailAvailabilityCheckSubject = PassthroughSubject<Void, Never>()

    private var subscriptions = Set<AnyCancellable>()

    // TODO: where do those names come from?
    private let excludedNames = [
        "aaa",
        "xxx"
    ]

    var emailAddressInput: String {
        "\(localPart.lowercased())@\(availableDomains[selectedDomainIndex])"
    }

    var isValidEmail: Bool {
        EmailAddress.isValid(emailAddressInput) && isEmailAvailable == true
    }

    private(set) var isValidName: Bool = true

    var showProgressIndicator: Bool {
        registrationStatus != .idle
    }

    init() {
        emailAvailabilityCheckSubject
            .debounce(for: 1, scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.checkEmailAvailability()
            }
            .store(in: &subscriptions)
    }

    func register() async {
        do {
            validateName()
            guard isValidName else { return }

            registrationStatus = .generatingKeys
            let fullName: String? = fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : fullName
            let user = try client.generateLocalUser(address: emailAddressInput, name: fullName)

            registrationStatus = .registeringAccount

            try await client.registerAccount(user: user, fullName: fullName)
            
            try keyStore.storeKeys(.init(
                privateEncryptionKey: user.privateEncryptionKeyBase64,
                privateSigningKey: user.privateSigningKeyBase64
            ))

            let defaults = UserDefaults.standard
            defaults.publicEncryptionKey = user.publicEncryptionKeyBase64
            defaults.publicEncryptionKeyId = user.publicEncryptionKeyId
            defaults.publicSigningKey = user.publicSigningKeyBase64
            defaults.profileName = fullName

            addInitialContacts()

            // Must be last!
            defaults.registeredEmailAddress = emailAddressInput
            registrationStatus = .idle
        } catch {
            Log.error("Error registering account: \(error)")
            alertConfiguration = .alertConfiguration(for: error)
            registrationStatus = .idle
        }
    }

    private func validateName() {
        isValidName = fullName.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minimumNameLength
    }

    private func checkEmailAvailability() {
        guard !localPart.isEmpty else {
            emailAvailabilityMessage = EmailAvailabilityMessage()
            isEmailAvailable = false
            return
        }

        guard
            !excludedNames.contains(localPart),
            EmailAddress.isValid(emailAddressInput)
        else {
            emailAvailabilityMessage = EmailAvailabilityMessage(
                imageName: "x.circle.fill",
                text: "Invalid email address.",
                color: Color(.systemRed)
            )
            return
        }

        Task {
            var isEmailAvailable = false
            if let emailAddress = EmailAddress(emailAddressInput) {
                isEmailAvailable = try await client.lookupAddressAvailability(address: emailAddress)
            }

            if isEmailAvailable {
                emailAvailabilityMessage = EmailAvailabilityMessage(
                    imageName: "checkmark.circle.fill",
                    text: "Looking great! Name is available.",
                    color: Color(.systemGreen)
                )
            } else {
                emailAvailabilityMessage = EmailAvailabilityMessage(
                    imageName: "x.circle.fill",
                    text: "Too bad! That name is not available.",
                    color: Color(.systemRed)
                )
            }

            self.isEmailAvailable = isEmailAvailable
        }
    }

    private func addInitialContacts() {
        let usecase = AddToContactsUseCase()

        Task {
            for address in Self.initialContactAddresses {
                guard let emailAddress = EmailAddress(address) else { continue }
                try await usecase.add(emailAddress: emailAddress, cachedName: nil)
            }
        }
    }
}

private extension AlertConfiguration {
    static func alertConfiguration(for error: Error) -> AlertConfiguration {
        var title: String?
        var message: String?

        if let registrationError = error as? RegistrationError {
            switch registrationError {
            case .accountAlreadyExists:
                title = "Account already exists"
                message = "Choose a different email address or log in with your existing address."
            case .provisioningError:
                title = "Provisioning error"
                message = "Please try again a bit later."
            }
        } else if let keychainError = error as? KeychainStoreError {
            switch keychainError {
            case .unexpectedStatus(let status):
                title = "Could not store keys"
                message = "Keychain status: \(status)"
            }
        }

        return AlertConfiguration(
            title: title ?? "Registering account failed.",
            message: message ?? error.localizedDescription
        )
    }
}

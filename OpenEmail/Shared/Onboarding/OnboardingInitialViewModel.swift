import Foundation
import Observation
import OpenEmailCore
import Logging
import Utils

@Observable
class OnboardingInitialViewModel {
    var isCheckingEmailAddress = false
    var showsServiceNotSupportedError = false

    @ObservationIgnored
    @Injected(\.client) private var client

    func registerExistingEmailAddress(_ emailAddress: String) async -> Bool {
        if let address = EmailAddress(emailAddress) {
            isCheckingEmailAddress = true
            do {
                let hosts = try await client.lookupHostsDelegations(address: address)
                isCheckingEmailAddress = false

                if hosts.isEmpty {
                    // Email v2 not supported
                    showsServiceNotSupportedError = true
                } else {
                    return true
                }
            } catch {
                Log.error("Could not verify address: \(error)")
                isCheckingEmailAddress = false
                showsServiceNotSupportedError = true
            }
        } else {
            // email address could not be created
            showsServiceNotSupportedError = true
        }

        return false
    }
}

import Foundation
import Observation
import SwiftUI
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel
import Logging

@Observable
class ProfileViewModel {
    var profile: Profile?
    private var profileLoadingError: Error?
    var isLoadingProfile = false

    var emailAddress: EmailAddress
    var isInContacts: Bool = false
    var isSelf: Bool = false

    @ObservationIgnored
    @Injected(\.client) private var client

    @ObservationIgnored
    @Injected(\.contactsStore) private var contactsStore: ContactStoring

    @ObservationIgnored
    @Injected(\.syncService) private var syncService

    var errorText: String {
        if let userError = profileLoadingError as? UserError {
            switch userError {
            case .emailV2notSupported:
                return "Email V2 protocol not supported"
            case .profileNotFound:
                return "No such user found"
            default:
                break
            }
        }

        return "Could not load user profile"
    }

    var onProfileLoaded: ((Profile?, Error?) -> Void)?

    var receiveBroadcasts = false {
        didSet {
            Task {
                await storeReceiveBroadcasts()
            }
        }
    }

    init(
        emailAddress: EmailAddress, 
        profile: Profile? = nil,
        shouldRefreshProfile: Bool = true,
        profileLoadingDelay: TimeInterval = 0,
        onProfileLoaded: ((Profile?, Error?) -> Void)? = nil
    ) {
        self.emailAddress = emailAddress
        self.profile = profile
        self.isSelf = LocalUser.current?.address == emailAddress
        self.onProfileLoaded = onProfileLoaded

        Task {
            if shouldRefreshProfile {
                await fetchProfile(delay: profileLoadingDelay)
            }
        }
    }

    private func fetchProfile(delay: TimeInterval = 0) async {
        guard !isLoadingProfile else { return }

        isLoadingProfile = true
        profileLoadingError = nil

        do {
            try await Task.sleep(seconds: delay)
            profile = try await client.fetchProfile(address: emailAddress, force: true)
            onProfileLoaded?(profile, nil)
        } catch {
            profileLoadingError = error
            onProfileLoaded?(nil, error)
            Log.error("Could not load profile: \(error)")
        }

        await updateIsInContacts()
        await updateReceiveBroadcasts()

        isLoadingProfile = false
    }

    @MainActor
    private func updateIsInContacts() async {
        isInContacts = (try? await contactsStore.contact(address: emailAddress.address)) != nil
    }

    @MainActor
    private func updateReceiveBroadcasts() async {
        guard let contact = (try? await contactsStore.contact(address: emailAddress.address)) else {
            return
        }

        receiveBroadcasts = contact.receiveBroadcasts
    }

    private func storeReceiveBroadcasts() async {
        guard var contact = (try? await contactsStore.contact(address: emailAddress.address)) else {
            return
        }

        contact.receiveBroadcasts = receiveBroadcasts
        try? await contactsStore.storeContact(contact)
    }

    func addToContacts() async throws {
        let usecase = AddToContactsUseCase()
        try await usecase.add(emailAddress: emailAddress, cachedName: profile?[.name])
        await updateIsInContacts()
    }

    func removeFromContacts() async throws {
        try await DeleteContactUseCase().deleteContact(emailAddress: emailAddress)

        await updateIsInContacts()
    }

    func refreshProfile() {
        Task {
            await fetchProfile()
        }
    }

    func fetchMessages() async {
        guard let profile else { return }
        let contact = (try? await contactsStore.contact(address: emailAddress.address))
        await syncService.fetchAuthorMessages(profile: profile, includeBroadcasts: contact?.receiveBroadcasts ?? false)
    }
}

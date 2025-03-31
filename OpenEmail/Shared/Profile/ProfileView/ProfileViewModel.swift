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

    var receiveBroadcasts: Bool? = nil
    
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
    
    func updateReceiveBroadcasts(_ newValue: Bool) async {
        let oldValue = receiveBroadcasts
        
        await MainActor.run {
            receiveBroadcasts = newValue
        }
        
        do {
            try await client.updateBroadcastsForContact(
                localUser: LocalUser.current!,
                address: emailAddress,
                allowBroadcasts: newValue
            )
        } catch {
            // Revert to old value on failure
            await MainActor.run {
                receiveBroadcasts = oldValue
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
        if let currentUser = LocalUser.current {
            let links = try? await client.getLinks(localUser: currentUser)
            let currentLink = links?.first {link in
                link.address == emailAddress
            }
            guard var contact = (try? await contactsStore.contact(address: emailAddress.address)) else {
                return
            }

            contact.receiveBroadcasts = currentLink?.allowedBroadcasts ?? true
            receiveBroadcasts = contact.receiveBroadcasts
        }
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

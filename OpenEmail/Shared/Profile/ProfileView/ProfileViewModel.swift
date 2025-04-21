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
    var profileLoadingError: Error?
    var isLoadingProfile = false
    
    var emailAddress: EmailAddress
    var isInContacts: Bool = false
    var isInOtherContacts: Bool?
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

    var receiveBroadcasts: Bool? = nil
    
    init(
        emailAddress: EmailAddress, 
        profile: Profile? = nil,
        shouldRefreshProfile: Bool = true,
    ) {
        self.emailAddress = emailAddress
        self.profile = profile
        self.isSelf = LocalUser.current?.address == emailAddress

        Task {
            if shouldRefreshProfile {
                await updateProfile()
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
    
    @MainActor
    private func updateProfile() async {
        guard !isLoadingProfile else { return }

        isLoadingProfile = true
        profileLoadingError = nil
        
        await withTaskGroup { group in
            group.addTask {
                await self.fetchProfile()
            }
            
            group.addTask {
                await self.updateIsInContacts()
            }
            
            group.addTask {
                await self.updateReceiveBroadcasts()
            }
            
            group.addTask {
                await self.checkOtherContacts()
            }
            
            await group.waitForAll()
        }

        isLoadingProfile = false
    }
    
    @MainActor
    private func checkOtherContacts() async {
        if let localUser = LocalUser.current {
            isInOtherContacts = try? await client.isAddressInContacts(localUser: localUser, address: emailAddress)
        }
    }
    
    @MainActor
    private func fetchProfile() async {
        do {
            self.profile = try await self.client.fetchProfile(address: self.emailAddress, force: true)
            self.profileLoadingError = nil
        } catch {
            self.profile = nil
            self.profileLoadingError = error
            Log.error("Could not load profile: \(error)")
        }
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
            await updateProfile()
        }
    }

    func fetchMessages() async {
        guard let profile else { return }
        let contact = (try? await contactsStore.contact(address: emailAddress.address))
        await syncService.fetchAuthorMessages(profile: profile, includeBroadcasts: contact?.receiveBroadcasts ?? false)
    }
}

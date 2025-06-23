import Foundation
import Observation
import SwiftUI
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel
import Logging

@Observable
class ProfileViewModel {
    var profile: Profile
    
    var isInContacts: Bool = true
    var isInOtherContacts: Bool?
    var isSelf: Bool = false
    
    @ObservationIgnored
    @Injected(\.client) private var client
    
    @ObservationIgnored
    @Injected(\.contactsStore) private var contactsStore: ContactStoring
    
    @ObservationIgnored
    @Injected(\.syncService) private var syncService


    var receiveBroadcasts: Bool = true
    
    init(
        profile: Profile,
        shouldRefreshProfile: Bool = true,
    ) {
        self.profile = profile
        self.isSelf = LocalUser.current?.address == profile.address

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
                address: profile.address,
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
        await withTaskGroup { group in
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
    }
    
    @MainActor
    private func checkOtherContacts() async {
        if let localUser = LocalUser.current {
            isInOtherContacts = try? await client.isAddressInContacts(localUser: localUser, address: profile.address)
        }
    }

    @MainActor
    private func updateIsInContacts() async {
        isInContacts = (try? await contactsStore.contact(address: profile.address.address)) != nil
    }

    @MainActor
    private func updateReceiveBroadcasts() async {
        if let currentUser = LocalUser.current {
            let links = try? await client.getLinks(localUser: currentUser)
            let currentLink = links?.first {link in
                link.address == profile.address
            }
            guard var contact = (try? await contactsStore.contact(address: profile.address.address)) else {
                return
            }

            contact.receiveBroadcasts = currentLink?.allowedBroadcasts ?? true
            receiveBroadcasts = contact.receiveBroadcasts
        }
    }

    

    func addToContacts() async throws {
        let usecase = AddToContactsUseCase()
        try await usecase.add(emailAddress: profile.address, cachedName: profile[.name])
        await updateIsInContacts()
    }

    func removeFromContacts() async throws {
        try await DeleteContactUseCase().deleteContact(emailAddress: profile.address)

        await updateIsInContacts()
    }

    func refreshProfile() {
        Task {
            await updateProfile()
        }
    }

    func fetchMessages() async {
        let contact = (try? await contactsStore.contact(address: profile.address.address))
        await syncService.fetchAuthorMessages(profile: profile, includeBroadcasts: contact?.receiveBroadcasts ?? true)
    }
}

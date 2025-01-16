import Foundation
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel

class AddToContactsUseCase {
    @Injected(\.contactsStore) private var contactsStore
    @Injected(\.client) private var client

    func add(emailAddress: EmailAddress, cachedName: String?) async throws {
        guard 
            let localUser = LocalUser.current,
            localUser.address.address != emailAddress.address 
        else { return }

        let id = localUser.connectionLinkFor(remoteAddress: emailAddress.address)

        try await client.storeContact(localUser: localUser, address: emailAddress)

        let contact = Contact(id: id, addedOn: Date(), address: emailAddress.address, receiveBroadcasts: true, cachedName: cachedName, cachedProfileImageURL: nil)
        try await contactsStore.storeContact(contact)
    }
}

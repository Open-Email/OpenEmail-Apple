import Foundation
import OpenEmailModel

extension Contact {
    func toPersisted() -> PersistedContact {
        PersistedContact(
            id: id,
            addedOn: addedOn,
            address: address,
            receiveBroadcasts: receiveBroadcasts, 
            name: cachedName,
            cachedProfileImageURL: cachedProfileImageURL
        )
    }
}

extension PersistedContact {
    func toLocal() -> Contact {
        Contact(
            id: id,
            addedOn: addedOn,
            address: address, 
            receiveBroadcasts: receiveBroadcasts,
            cachedName: name,
            cachedProfileImageURL: cachedProfileImageURL
        )
    }
}

import Foundation
import OpenEmailPersistence
import OpenEmailCore

class ContactRequestsController {
    @Injected(\.contactsStore) private var contactsStore
    @Injected(\.notificationsStore) private var notificationsStore

    var hasContactRequests: Bool {
        get async {
            await !contactRequests.isEmpty
        }
    }

    var contactRequests: [EmailAddress] {
        get async {
            let notifications = (try? await notificationsStore.allNotifications()) ?? []
            var notificationLinkIDs = notifications.filter({ !$0.isProcessed && !$0.isExpired() }).map { $0.link }
            if let localUser = LocalUser.current {
                let selfLink = localUser.connectionLinkFor(remoteAddress: localUser.address.address)
                notificationLinkIDs = notificationLinkIDs.filter { $0 != selfLink }
            }

            let contactIDs = (try? await contactsStore.allContacts().map { $0.id }) ?? []
            let contactRequestIDs = Set(notificationLinkIDs).subtracting(contactIDs)

            let contactRequestNotifications = notifications.filter {
                contactRequestIDs.contains($0.link)
            }

            return contactRequestNotifications.compactMap {
                guard let address = $0.address else { return nil }
                return EmailAddress(address)
            }
        }
    }
}

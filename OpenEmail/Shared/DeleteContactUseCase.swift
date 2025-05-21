import Foundation
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel

class DeleteContactUseCase {
    @Injected(\.contactsStore) private var contactsStore
    @Injected(\.notificationsStore) private var notificationsStore: NotificationStoring
    @Injected(\.client) private var client

    func deleteContact(emailAddress: EmailAddress) async throws {
        guard let localUser = LocalUser.current else { return }

        let link = localUser.connectionLinkFor(remoteAddress: emailAddress.address)
        try await contactsStore.deleteContact(id: link)
        try await notificationsStore.markAsProcessed(link: link)

        Task.detached {
            try await self.client.deleteContact(localUser: localUser, address: emailAddress)
        }
    }
}

import Foundation
import Observation
import Combine
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence
import Logging

enum AddContactError: Error {
    case invalidAddress
    case noCurrentUser
    case noProfileFound
    case selfAddress
}

struct ContactListItem: Equatable, Identifiable, Hashable {
    let title: String
    let subtitle: String?
    let email: String
    let isContactRequest: Bool

    var id: String { email }
}

@Observable
class ContactsListViewModel {

    @ObservationIgnored
    @Injected(\.client) private var client

    @ObservationIgnored
    @Injected(\.contactsStore) private var contactsStore

    private let contactRequestController = ContactRequestsController()

    private var contacts: [Contact] = []
    private var contactRequests: [EmailAddress] = []
    var contactToAdd: Profile?
    var showsContactExistsError = false

    private var subscriptions = Set<AnyCancellable>()

    var searchText = "" {
        didSet {
            Task { await reloadContacts() }
        }
    }

    var contactRequestItems: [ContactListItem] {
        contactRequests
            .sorted()
            .map {
                ContactListItem(title: $0.address, subtitle: nil, email: $0.address, isContactRequest: true)
            }
    }

    var contactItems: [ContactListItem] {
        contacts
            .sorted {
                let lhs = $0.cachedName ?? $0.address
                let rhs = $1.cachedName ?? $1.address
                return lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
            .map {
                let title: String
                let subtitle: String?

                if let name = $0.cachedName {
                    title = name
                    subtitle = $0.address
                } else {
                    title = $0.address
                    subtitle = nil
                }

                return ContactListItem(title: title, subtitle: subtitle, email: $0.address, isContactRequest: false)
            }
    }

    var contactsCount: Int {
        contacts.count
    }

    init() {
        Publishers.Merge(
            NotificationCenter.default.publisher(for: .didUpdateNotifications),
            NotificationCenter.default.publisher(for: .didUpdateContacts)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            let updateType = PersistedStore.UpdateType(rawValue: ((notification.userInfo?["type"] as? String) ?? "")) ?? .add

            if updateType != .update {
                self?.reloadContent()
            }
        }
        .store(in: &subscriptions)

        reloadContent()
    }

    func onAddressSearch(address: String) {
        if hasContact(with: address) {
            showsContactExistsError = true
        } else {
            if let emailAddress = EmailAddress(address) {
                Task {
                    contactToAdd = try? await client
                        .fetchProfile(address: emailAddress, force: false)
                }
            }
        }
    }
    
    func  onAddressSearchDismissed() {
        contactToAdd = nil
    }
    
    private func reloadContent() {
        Task {
            await withTaskGroup(of: Void.self) { taskGroup in
                taskGroup.addTask {
                    await self.reloadContacts()
                }
                taskGroup.addTask {
                    await self.reloadContactRequests()
                }
                await taskGroup.waitForAll()
            }
        }
    }

    @MainActor
    private func reloadContacts() async {
        do {
            contacts.removeAll()
            
            if searchText.isEmpty {
                contacts.append(contentsOf: try await contactsStore.allContacts().distinctBy{ element in
                    element.address
                })
            } else {
                contacts
                    .append(
                        contentsOf: try await contactsStore
                            .findContacts(containing: searchText)
                            .distinctBy{ element in
                                element.address
                            }
                    )
            }

            Log.info("reloaded \(contacts.count) contacts")
        } catch {
            // TODO: show error message?
            Log.error("Error: could not get contacts from store:", context: error)
        }
    }
    
    private func reloadContactRequests() async {
        contactRequests.removeAll()
        contactRequests
            .append(
                contentsOf: await contactRequestController.contactRequests
                    .distinctBy { element in
                        element.address
                    }
            )
    }

    func hasContact(with emailAddress: String) -> Bool {
        contacts.first { $0.address == emailAddress } != nil
    }

    func contactListItem(with emailAddress: String) -> ContactListItem? {
        contactItems.first { $0.email == emailAddress }
    }

    func addContact() async throws {
        guard let profile = contactToAdd else {
            throw AddContactError.noProfileFound
        }
        
        guard let localUser = LocalUser.current else {
            throw AddContactError.noCurrentUser
        }

        guard localUser.address.address != profile.address.address else {
            throw AddContactError.selfAddress
        }

        let id = localUser.connectionLinkFor(remoteAddress: profile.address.address)

        let contact = Contact(
            id: id,
            addedOn: Date(),
            address: profile.address.address,
            receiveBroadcasts: true,
            cachedName: profile[.name],
            cachedProfileImageURL: nil
        )

        try await contactsStore.storeContact(contact)
        contactToAdd = nil
        Task.detached { [weak self] in
            guard let self else { return }
            try await client.storeContact(localUser: localUser, address: profile.address)
        }

        // Once the contact is added, fetch any pending messages from that contact.
        // The notification implied there was a message.
        Task.detached { [weak self] in
            guard let self else { return }
            try await client.fetchRemoteMessages(localUser: localUser, authorProfile: profile)
        }
    }
}

private extension String {
    var diacriticInsensitive: String {
        folding(options: .diacriticInsensitive, locale: nil)
    }
}

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

protocol ContactsListViewModelProtocol {
    var contactRequestItems: [ContactListItem] { get }
    var contactItems: [ContactListItem] { get }
    var searchText: String { get set }
    var contactsCount: Int { get }

    func hasContact(with emailAddress: String) -> Bool
    func contactListItem(with emailAddress: String) -> ContactListItem?
    func addContact(address: String) async throws
}

@Observable
class ContactsListViewModel: ContactsListViewModelProtocol {
    @ObservationIgnored
    @Injected(\.client) private var client

    @ObservationIgnored
    @Injected(\.contactsStore) private var contactsStore

    private let contactRequestController = ContactRequestsController()

    private var contacts: [Contact] = []
    private var contactRequests: [EmailAddress] = []

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

    func addContact(address: String) async throws {
        guard let localUser = LocalUser.current else {
            throw AddContactError.noCurrentUser
        }

        guard let emailAddress = EmailAddress(address) else {
            throw AddContactError.invalidAddress
        }

        guard localUser.address.address != emailAddress.address else {
            throw AddContactError.selfAddress
        }

        guard let profile = try await client.fetchProfile(address: emailAddress, force: true) else {
            throw AddContactError.noProfileFound
        }

        let id = localUser.connectionLinkFor(remoteAddress: emailAddress.address)

        let contact = Contact(
            id: id,
            addedOn: Date(),
            address: emailAddress.address,
            receiveBroadcasts: true,
            cachedName: profile[.name],
            cachedProfileImageURL: nil
        )

        try await contactsStore.storeContact(contact)
        Task.detached { [weak self] in
            guard let self else { return }
            try await client.storeContact(localUser: localUser, address: emailAddress)
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

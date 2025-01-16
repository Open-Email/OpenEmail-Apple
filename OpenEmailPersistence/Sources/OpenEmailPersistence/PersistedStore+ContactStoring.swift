import Foundation
import SwiftData
import OpenEmailModel

public protocol ContactStoring {
    func storeContact(_ contact: Contact) async throws
    func storeContacts(_ contacts: [Contact]) async throws
    func contact(address: String) async throws -> Contact?
    func contact(id: String) async throws -> Contact?
    func allContacts() async throws -> [Contact]
    func deleteContact(id: String) async throws
    func deleteAllContacts() async throws
    func findContacts(containing: String) async throws -> [Contact]
}

public extension Foundation.Notification.Name {
    static let didUpdateContacts = Self.init("didUpdateContacts")
}

extension PersistedStore: ContactStoring {
    public func storeContact(_ contact: Contact) async throws {
        try await storeContacts([contact])
    }

    public func storeContacts(_ contacts: [Contact]) async throws {
        var didAddNewContact = false

        for contact in contacts {
            // determine if contact already exists
            if !didAddNewContact {
                let existingContact = try? await fetchPersistedContact(id: contact.id)
                if existingContact == nil {
                    didAddNewContact = true
                }
            }

            let persisted = contact.toPersisted()
            modelContext.insert(persisted)
        }

        try modelContext.save()
        await postUpdateNotification(
            type: didAddNewContact ? .add : .update,
            addresses: contacts.map { $0.address }
        )
    }

    public func contact(id: String) async throws -> Contact? {
        try await fetchPersistedContact(id: id)?.toLocal()
    }

    public func contact(address: String) async throws -> Contact? {
        try await fetchPersistedContact(address: address)?.toLocal()
    }

    private func fetchPersistedContact(id: String) async throws -> PersistedContact? {
        let fetch = FetchDescriptor<PersistedContact>(
            predicate: #Predicate { $0.id == id }
        )

        let results = try modelContext.fetch(fetch)
        return results.first
    }

    private func fetchPersistedContact(address: String) async throws -> PersistedContact? {
        let fetch = FetchDescriptor<PersistedContact>(
            predicate: #Predicate { $0.address == address }
        )

        let results = try modelContext.fetch(fetch)
        return results.first
    }

    public func allContacts() async throws -> [Contact] {
        var fetch = FetchDescriptor<PersistedContact>()
        fetch.includePendingChanges = true

        let results = try modelContext.fetch(fetch)
        return results.map { $0.toLocal() }
    }

    public func deleteContact(id: String) async throws {
        try modelContext.delete(
            model: PersistedContact.self,
            where: #Predicate { $0.id == id }
        )

        try modelContext.save()
        await postUpdateNotification(type: .delete)
    }

    public func deleteAllContacts() async throws {
        try modelContext.delete(model: PersistedContact.self)
        try modelContext.save()
        await postUpdateNotification(type: .delete)
    }

    public func findContacts(containing searchText: String) async throws -> [Contact] {
        let predicate = #Predicate<PersistedContact> { contact in
            searchText.isEmpty ||
            (contact.name?.localizedStandardContains(searchText)) ?? false ||
            contact.address.localizedStandardContains(searchText)
        }

        var fetch = FetchDescriptor<PersistedContact>(predicate: predicate)
        fetch.includePendingChanges = true

        let results = try modelContext.fetch(fetch)
        return results.map { $0.toLocal() }
    }

    @MainActor
    private func postUpdateNotification(type: UpdateType, addresses: [String]? = nil) {
        let userInfo: [String: Any] = [
            "type": type.rawValue,
            "addresses": (addresses ?? [])
        ]

        NotificationCenter.default.post(name: .didUpdateContacts, object: nil, userInfo: userInfo)
    }
}

import Foundation
import OpenEmailModel
import OpenEmailPersistence

#if DEBUG
class ContactStoreMock: ContactStoring {
    var stubContacts: [Contact] = [
        .init(id: "1", addedOn: .now, address: "mickey@mouse.com", cachedName: "Mickey Mouse"),
        .init(id: "2", addedOn: .now, address: "minnie@mouse.com", cachedName: "Minnie Mouse"),
        .init(id: "3", addedOn: .now, address: "donald@duck.com", cachedName: "Donald Duck"),
    ]

    func storeContact(_ contact: Contact) throws {
    }
    
    func storeContacts(_ contacts: [Contact]) throws {
    }
    
    func contact(id: String) throws -> Contact? {
        stubContacts.first { $0.id == id }
    }

    func contact(address: String) throws -> Contact? {
        stubContacts.first { $0.address == address }
    }

    func allContacts() throws -> [Contact] {
        return stubContacts
    }
    
    func deleteContact(id: String) throws {
    }
    
    func deleteAllContacts() throws {
    }
    
    func findContacts(containing: String) throws -> [Contact] {
        return []
    }
}
#endif

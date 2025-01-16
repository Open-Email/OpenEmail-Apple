import Foundation
import OpenEmailModel
import OpenEmailPersistence

#if DEBUG
class ContactStoreMock: ContactStoring {
    func storeContact(_ contact: Contact) throws {
    }
    
    func storeContacts(_ contacts: [Contact]) throws {
    }
    
    func contact(id: String) throws -> Contact? {
        return nil
    }

    func contact(address: String) throws -> Contact? {
        return nil
    }

    func allContacts() throws -> [Contact] {
        return []
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

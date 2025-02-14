import OpenEmailModel

final class ContactsListViewModelMock: ContactsListViewModelProtocol {   
    var contactRequestItems: [ContactListItem]
    var contactItems: [ContactListItem]
    var searchText: String
    var contactsCount: Int {
        contactItems.count
    }

    init(
        contactRequestItems: [ContactListItem] = [],
        contactItems: [ContactListItem] = [],
        searchText: String = ""
    ) {
        self.contactRequestItems = contactRequestItems
        self.contactItems = contactItems
        self.searchText = searchText
    }

    func hasContact(with emailAddress: String) -> Bool {
        false
    }

    func contactListItem(with emailAddress: String) -> ContactListItem? {
        nil
    }

    func addContact(address: String) async throws {}

    static func makeMock() -> ContactsListViewModelMock {
        ContactsListViewModelMock(
            contactRequestItems: [
                .init(title: "Minnie", subtitle: "minnie@mouse.com", email: "minnie@mouse.com", isContactRequest: true),
                .init(title: "Mickey", subtitle: "mickey@mouse.com", email: "mickey@mouse.com", isContactRequest: true),
            ],
            contactItems: [
                .init(title: "Donald", subtitle: "donald@duck.com", email: "donald@duck.com", isContactRequest: false),
                .init(title: "Daisy", subtitle: "daisy@duck.com", email: "daisy@duck.com", isContactRequest: false),
                .init(title: "Goofy", subtitle: "goofy@duck.com", email: "goofy@duck.com", isContactRequest: false),
                .init(title: "Scrooge", subtitle: "scrooge@duck.com", email: "scrooge@duck.com", isContactRequest: false),
            ]
        )
    }
}

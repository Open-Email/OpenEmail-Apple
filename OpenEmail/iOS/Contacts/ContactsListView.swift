import SwiftUI
import OpenEmailModel
import OpenEmailPersistence
import OpenEmailCore
import Logging

struct ContactsListView: View {
    @State private var viewModel: ContactsListViewModelProtocol
    @State private var searchText = ""

    @State private var showAddContactView = false
    @State private var addressToAdd: String = ""

    @State private var showsAddContactError = false
    @State private var showsContactExistsError = false
    @State private var addContactError: Error?
    @State private var didLoadProfile = false

    @Binding private var selectedContactListItem: ContactListItem?

    init(
        viewModel: ContactsListViewModelProtocol = ContactsListViewModel(),
        selectedContactListItem: Binding<ContactListItem?>
    ) {
        _viewModel = .init(initialValue: viewModel)
        _selectedContactListItem = selectedContactListItem
    }

    var body: some View {
        List(selection: $selectedContactListItem) {
            let hasContactRequests = !viewModel.contactRequestItems.isEmpty

            if hasContactRequests {
                Section("Contact Requests (\(viewModel.contactRequestItems.count))") {
                    ForEach(viewModel.contactRequestItems) { item in
                        ContactListItemView(item: item).tag(item)
                    }
                }
            }

            if viewModel.contactsCount > 0 {
                Section(hasContactRequests ? "Contacts" : "") {
                    ForEach(viewModel.contactItems) { item in
                        ContactListItemView(item: item).tag(item)
                    }
                }
            }
        }
        .listStyle(.grouped)
        .searchable(text: $searchText)
        .navigationTitle("Contacts")
        .toolbar {
            ToolbarItem {
                Button("Add Contact", image: .addContact) {
                    showAddContactView = true
                }
            }
        }
        .overlay {
            if viewModel.contactRequestItems.isEmpty && viewModel.contactsCount == 0 && searchText.isEmpty {
                EmptyListView(
                    icon: SidebarScope.contacts.imageResource,
                    text: "Your contact list is empty."
                )
            }
        }
        .onChange(of: searchText) {
            viewModel.searchText = searchText
        }
        .onChange(of: viewModel.contactsCount) {
            // deselect contact if it has been removed
            if let selectedContactListItem {
                self.selectedContactListItem = viewModel.contactListItem(with: selectedContactListItem.email)
            }
        }
        .alert("Add Contact", isPresented: $showAddContactView) {
            TextField("Contact Email", text: $addressToAdd)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)

            Button("Add") {
                if viewModel.hasContact(with: addressToAdd) {
                    showsContactExistsError = true
                    addressToAdd = ""
                }

                showAddContactView = false
            }
            .disabled(!EmailAddress.isValid(addressToAdd))

            Button("Cancel", role: .cancel) {
                addressToAdd = ""
                showAddContactView = false
            }
        }
        .sheet(isPresented: Binding(get: {
            EmailAddress.isValid(addressToAdd) && !showAddContactView && !showsContactExistsError
        }, set: {
            if $0 == false {
                addressToAdd = ""
            }
        })) {
            if let emailAddress = EmailAddress(addressToAdd) {
                NavigationStack {
                    ProfileView(emailAddress: emailAddress, showActionButtons: true)
                        .profilePopoverToolbar {
                            addressToAdd = ""
                            showAddContactView = true
                        }
                }
            }
        }
        .alert("Could not add contact", isPresented: $showsAddContactError, actions: {
            Button("OK") {
                showAddContactView = true
            }
        }, message: {
            if let addContactError {
                Text("Underlying error: \(String(describing: addContactError))")
            }
        })
        .alert("Contact already exists", isPresented: $showsContactExistsError, actions: {})
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateContacts)) { notification in
            // listen to contact add notification
            guard
                let userInfo = notification.userInfo,
                let updateType = PersistedStore.UpdateType(rawValue: ((userInfo["type"] as? String) ?? "")),
                updateType == .add,
                let addresses = userInfo["addresses"] as? [String],
                !addressToAdd.isEmpty,
                addresses.contains(addressToAdd)
            else {
                return
            }

            self.addressToAdd = ""
        }
    }
}

#if DEBUG

#Preview {
    @Previewable @State var selectedContactListItem: ContactListItem?

    let viewModel = ContactsListViewModelMock.makeMock()
    ContactsListView(viewModel: viewModel, selectedContactListItem: $selectedContactListItem)
}

#Preview("empty") {
    @Previewable @State var selectedContactListItem: ContactListItem?
    let viewModel = ContactsListViewModelMock()
    ContactsListView(viewModel: viewModel, selectedContactListItem: $selectedContactListItem)
}

#endif

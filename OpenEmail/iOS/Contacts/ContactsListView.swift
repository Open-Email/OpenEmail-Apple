import SwiftUI
import OpenEmailModel
import OpenEmailPersistence
import OpenEmailCore
import Logging

struct ContactsListView: View {
    @State private var viewModel = ContactsListViewModel()
    @Injected(\.client) private var client
    @State private var searchText = ""

    @State private var showAddContactView = false
    @State private var addressToAdd: String = ""
    @State private var profileToAdd: Profile? = nil

    @State private var showsAddContactError = false
    @State private var showsContactExistsError = false
    @State private var addContactError: Error?
    @State private var didLoadProfile = false

    @Binding private var selectedContactListItem: ContactListItem?

    init(
        selectedContactListItem: Binding<ContactListItem?>
    ) {
        _selectedContactListItem = selectedContactListItem
    }
    
    private var hasContactRequests: Bool {
        !viewModel.contactRequestItems.isEmpty
    }

    var body: some View {
        List(selection: $selectedContactListItem) {
            if hasContactRequests {
                Section("Contact Requests (\(viewModel.contactRequestItems.count))") {
                    ForEach(viewModel.contactRequestItems) { item in
                        ContactListItemView(item: item).tag(item)
                    }
                }
            }

            if viewModel.contactsCount > 0 {
                if hasContactRequests {
                    Section("Contacts") {
                        ForEach(viewModel.contactItems) { item in
                            ContactListItemView(item: item).tag(item)
                        }
                    }
                } else {
                    ForEach(viewModel.contactItems) { item in
                        ContactListItemView(item: item).tag(item)
                    }
                }
            }
        }
        .if(hasContactRequests) { view in
            view.listStyle(.grouped)
        }
        .if(!hasContactRequests) { view in
            view.listStyle(.plain)
        }
        
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
        .onChange(of: addressToAdd) {
            if let emailAddress = EmailAddress(addressToAdd) {
                Task {
                    profileToAdd = try? await client
                        .fetchProfile(
                            address: emailAddress,
                            force: false
                        )
                }
            }
            
        }
        .sheet(isPresented: Binding(get: {
            profileToAdd != nil
        }, set: {
            if $0 == false {
                profileToAdd = nil
                addressToAdd = ""
            }
        })) {
            NavigationStack {
                ProfileView(profile: profileToAdd!, showActionButtons: true)
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

    ContactsListView(selectedContactListItem: $selectedContactListItem)
}

#Preview("empty") {
    @Previewable @State var selectedContactListItem: ContactListItem?
    let viewModel = ContactsListViewModelMock()
    ContactsListView(selectedContactListItem: $selectedContactListItem)
}

#endif

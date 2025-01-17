import SwiftUI
import OpenEmailModel
import OpenEmailPersistence
import OpenEmailCore
import Logging

struct ContactsListView: View {
    @State private var viewModel: ContactsListViewModelProtocol
    @State private var searchText = ""

    @State private var showAddContactView = false
    @State private var addressToAdd: String?

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
        VStack(alignment: .leading, spacing: 0) {
            SearchField(text: $searchText)
                .padding(.vertical, .Spacing.small)
                .padding(.horizontal, .Spacing.default)

            Divider()

            List(selection: $selectedContactListItem) {
                Section {
                    if viewModel.contactRequestItems.isEmpty && viewModel.contactsCount == 0 && searchText.isEmpty {
                        EmptyListView(
                            icon: SidebarScope.contacts.imageResource,
                            text: "Your contact list is empty."
                        )
                    }
                    
                    let hasContactRequests = !viewModel.contactRequestItems.isEmpty
                    
                    if hasContactRequests {
                        Text("Contact Requests (\(viewModel.contactRequestItems.count))")
                            .fontWeight(.semibold)
                            .listRowSeparator(.hidden)
                            .padding(.horizontal, .Spacing.xSmall)
                        
                        ForEach(viewModel.contactRequestItems) { item in
                            ContactListItemView(item: item).tag(item)
                        }
                    }
                    
                    if viewModel.contactsCount > 0 {
                        if hasContactRequests {
                            Divider()
                                .padding(.horizontal, -.Spacing.xxSmall)
                                .listRowSeparator(.hidden)
                        }
                        
                        ForEach(viewModel.contactItems) { item in
                            ContactListItemView(item: item).tag(item)
                        }
                    }
                } header: {
                    HStack {
                        Text(SidebarScope.contacts.displayName)
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Button {
                            showAddContactView = true
                        } label: {
                            HStack(spacing: .Spacing.xxxSmall) {
                                Image(.addContact)
                                Text("Add Contact")
                            }
                            .fontWeight(.semibold)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.Spacing.default)
                }
            }
            .listStyle(.plain)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: searchText) {
            viewModel.searchText = searchText
        }
        .onChange(of: viewModel.contactsCount) {
            // deselect contact if it has been removed
            if let selectedContactListItem {
                self.selectedContactListItem = viewModel.contactListItem(with: selectedContactListItem.email)
            }
        }
        .sheet(isPresented: $showAddContactView) {
            ContactsAddressInputView { address in
                if viewModel.hasContact(with: address) {
                    showsContactExistsError = true
                } else {
                    addressToAdd = address
                }
                showAddContactView = false
            } onCancel: {
                addressToAdd = nil
                showAddContactView = false
            }
        }
        .sheet(isPresented: Binding(get: {
            addressToAdd != nil
        }, set: {
            if $0 == false {
                addressToAdd = nil
            }
        })) {
            if let emailAddress = EmailAddress(addressToAdd) {
                profilePreviewSheetView(emailAddress: emailAddress)
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
                let addressToAdd,
                addresses.contains(addressToAdd)
            else {
                return
            }

            self.addressToAdd = nil
        }
    }

    @ViewBuilder
    private func profilePreviewSheetView(emailAddress: EmailAddress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileView(
                viewModel: ProfileViewModel(emailAddress: emailAddress, onProfileLoaded: { profile, error in
                    didLoadProfile = profile != nil && error == nil
                }),
                showActionButtons: false,
                profileImageSize: 240
            )
            .padding(.top, -.Spacing.xSmall)

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) {
                    addressToAdd = nil
                    showAddContactView = true
                }

                if didLoadProfile {
                    AsyncButton("Add", role: .cancel) {
                        do {
                            try await viewModel.addContact(address: emailAddress.address)
                        } catch {
                            Log.error("Error while adding contact: \(error)")
                            addContactError = error
                            showsAddContactError = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(emailAddress.address == LocalUser.current?.address.address)
                }
            }
            .padding(.horizontal, .Spacing.default)
            .padding(.bottom, .Spacing.default)
        }
        .frame(width: 600)
        .frame(maxHeight: 600)
        .background(.themeViewBackground)
    }
}

#if DEBUG

private final class ContactsListViewModelMock: ContactsListViewModelProtocol {   
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
}

#Preview {
    @Previewable @State var selectedContactListItem: ContactListItem?

    let viewModel = ContactsListViewModelMock(
        contactItems: [
            .init(title: "Donald", subtitle: "donald@duck.com", email: "donald@duck.com", isContactRequest: false),
            .init(title: "Daisy", subtitle: "daisy@duck.com", email: "daisy@duck.com", isContactRequest: false),
            .init(title: "Goofy", subtitle: "goofy@duck.com", email: "goofy@duck.com", isContactRequest: false),
            .init(title: "Scrooge", subtitle: "scrooge@duck.com", email: "scrooge@duck.com", isContactRequest: false),
        ]
    )

    ContactsListView(viewModel: viewModel, selectedContactListItem: $selectedContactListItem)
        .frame(width: 300, height: 600)
}

#Preview("empty") {
    @Previewable @State var selectedContactListItem: ContactListItem?
    let viewModel = ContactsListViewModelMock()
    ContactsListView(viewModel: viewModel, selectedContactListItem: $selectedContactListItem)
        .frame(width: 300, height: 600)
}

#endif

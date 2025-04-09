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
                ProfilePreviewSheetView(
                    emailAddress: emailAddress,
                    onAddContactClicked: { address in
                        Task {
                            do {
                                try await viewModel.addContact(address: emailAddress.address)
                            } catch {
                                Log.error("Error while adding contact: \(error)")
                                addContactError = error
                                showsAddContactError = true
                            }
                        }
                    }
                )
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

    struct ProfilePreviewSheetView: View {
        @Environment(\.dismiss) private var dismiss
        @StateObject var profileViewModel: ProfileViewModel
        let emailAddress: EmailAddress
        let onAddContactClicked: ((String) -> Void)

        init(
            emailAddress: EmailAddress,
            onAddContactClicked: @escaping ((String) -> Void)
        ) {
            self.emailAddress = emailAddress
            self.onAddContactClicked = onAddContactClicked
            _profileViewModel = StateObject(
                wrappedValue: ProfileViewModel(
                    emailAddress: emailAddress,
                    onProfileLoaded: { _, _ in }
                )
            )
        }
        
        var body: some View {
            
            let profileLoaded = profileViewModel.profile != nil && profileViewModel.profileLoadingError == nil
            
            VStack(alignment: .leading, spacing: 0) {
                ProfileView(
                    viewModel: profileViewModel,
                    showActionButtons: false,
                    profileImageSize: 240
                )
                .padding(.top, -.Spacing.xSmall)

                HStack {
                    Spacer()

                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }

                    if profileLoaded {
                        Button("Add", role: .cancel) {
                            onAddContactClicked(emailAddress.address)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(emailAddress.address == LocalUser.current?.address.address)
                    }
                }
                .padding(.horizontal, .Spacing.default)
                .padding(.bottom, .Spacing.default)
            }
            //.frame(width: 600, height: 600)
            .background(.themeViewBackground)
        }
    }

}

#if DEBUG

#Preview {
    @Previewable @State var selectedContactListItem: ContactListItem?

    let viewModel = ContactsListViewModelMock.makeMock()
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

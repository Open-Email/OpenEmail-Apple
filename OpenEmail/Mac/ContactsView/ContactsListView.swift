import SwiftUI
import OpenEmailModel
import OpenEmailPersistence
import OpenEmailCore
import Logging

struct ContactsListView: View {
    @State private var viewModel: ContactsListViewModel = ContactsListViewModel()
    @Binding private var searchText: String
    @Environment(NavigationState.self) private var navigationState

    @State private var showAddContactView = false

    @State private var showsAddContactError = false
    @State private var addContactError: Error?

    init(searchText: Binding<String>) {
        _searchText = searchText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
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
        .onChange(of: searchText) {
            viewModel.searchText = searchText
        }
        .sheet(isPresented: $showAddContactView) {
            ContactsAddressInputView { address in
                viewModel.onAddressSearch(address: address)
                showAddContactView = false
            } onCancel: {
                viewModel.onAddressSearchDismissed()
                showAddContactView = false
            }
        }.alert("Could not add contact", isPresented: $showsAddContactError, actions: {
            Button("OK") {
                showAddContactView = true
            }
        }, message: {
            if let addContactError {
                Text("Underlying error: \(String(describing: addContactError))")
            }
        })
        .alert("Contact already exists", isPresented: $viewModel.showsContactExistsError, actions: {})
                
//        VStack(alignment: .leading, spacing: 0) {
//
//
//        }

//        .onChange(of: viewModel.contactsCount) {
//            // deselect contact if it has been removed
//            if let selectedContactListItem {
//                self.selectedContactListItem = viewModel.contactListItem(with: selectedContactListItem.email)
//            }
//        }
//
//        .sheet(isPresented: Binding<Bool>(
//            get: {
//                $viewModel.contactToAdd != nil
//            },
//            set: { _ in }
//        )) {
//            ProfilePreviewSheetView(
//                profile: $viewModel.contactToAdd!,
//                onAddContactClicked: { address in
//                    Task {
//                        do {
//                            try await viewModel.addContact()
//                        } catch {
//                            Log.error("Error while adding contact: \(error)")
//                            addContactError = error
//                            showsAddContactError = true
//                        }
//                    }
//                }
//            )
//            
//        }
//
    }

    private struct ProfilePreviewSheetView: View {
        @Environment(\.dismiss) private var dismiss
        @State var profileViewModel: ProfileViewModel
        let profile: Profile
        let onAddContactClicked: ((Profile) -> Void)

        init(
            profile: Profile,
            onAddContactClicked: @escaping ((Profile) -> Void)
        ) {
            self.profile = profile
            self.onAddContactClicked = onAddContactClicked
            profileViewModel = ProfileViewModel(
                emailAddress: profile.address,
            )
        }
        
        var body: some View {
            
            let profileLoaded = profileViewModel.profileLoadingError == nil
            
            VStack(alignment: .leading, spacing: 0) {
                ProfileView(
                    address: profileViewModel.emailAddress,
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
                            onAddContactClicked(profile)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(profileViewModel.profile!.address == LocalUser.current?.address)
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
    ContactsListView(
        searchText: Binding<String>(
            get: { "" }, set: { _ in }
        )
    )
        .frame(width: 300, height: 600)
}

#Preview("empty") {
    @Previewable @State var selectedContactListItem: ContactListItem?
    ContactsListView(
        searchText: Binding<String>(
            get: { "" }, set: { _ in }
        )
    )
        .frame(width: 300, height: 600)
}

#endif

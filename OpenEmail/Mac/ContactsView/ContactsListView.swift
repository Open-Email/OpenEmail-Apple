import SwiftUI
import OpenEmailModel
import OpenEmailPersistence
import OpenEmailCore
import Logging

struct ContactsListView: View {
    @State private var viewModel = ContactsListViewModel()
    @State var selectedContact: ContactListItem?
    @Injected(\.client) private var client
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedContact) {
                if viewModel.contactRequestItems.isEmpty && viewModel.contactsCount == 0 && viewModel.searchText.isEmpty {
                    EmptyListView(
                        icon: SidebarScope.contacts.imageResource,
                        text: "Your contact list is empty."
                    )
                } else {
                    ForEach(viewModel.contactRequestItems + viewModel.contactItems) { item in
                        ContactListItemView(item: item)
                            .alignmentGuide(.listRowSeparatorLeading) { d in
                                d[.leading]
                            }
                            .tag(item)
                            .id(item)
                    }
                }
            }
            .listStyle(.automatic)
            .scrollBounceBehavior(.basedOnSize)
            .frame(idealWidth: 200)
        } detail: {
            ContactDetailView(selectedContact: selectedContact)
                .id(selectedContact?.email)
        }
    }
}

#if DEBUG

#Preview {
    @Previewable @State var selectedContactListItem: ContactListItem?
    ContactsListView().frame(width: 300, height: 600)
}

#Preview("empty") {
    @Previewable @State var selectedContactListItem: ContactListItem?
    ContactsListView().frame(width: 300, height: 600)
}

#endif

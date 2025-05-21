import SwiftUI
import OpenEmailModel
import OpenEmailPersistence
import OpenEmailCore
import Logging

struct ContactsListView: View {
    @Binding private var viewModel: ContactsListViewModel
    @Environment(NavigationState.self) private var navigationState
    
    init(contactsListViewModel: Binding<ContactsListViewModel>) {
        _viewModel = contactsListViewModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: Binding(
                get:   { navigationState.selectedContact },
                set:   { navigationState.selectedContact = $0 }
            )) {
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
        }.frame(idealWidth: 200)
    }
}

#if DEBUG

#Preview {
    @Previewable @State var selectedContactListItem: ContactListItem?
    ContactsListView(
        contactsListViewModel: Binding<ContactsListViewModel>(
            get: {
                ContactsListViewModel()
            },
            set: {_ in}
        ),
        
    )
    .frame(width: 300, height: 600)
}

#Preview("empty") {
    @Previewable @State var selectedContactListItem: ContactListItem?
    ContactsListView(
        contactsListViewModel: Binding<ContactsListViewModel>(
            get: {
                ContactsListViewModel()
            },
            set: {_ in}
        ),
        
    )
    .frame(width: 300, height: 600)
}

#endif

import SwiftUI
import OpenEmailCore

struct ContactsTabView: View {
    @Environment(NavigationState.self) private var navigationState
    
    
    var body: some View {
        NavigationSplitView {
            ContactsListView(
                selectedContactListItem: Binding<ContactListItem?>(
                    get: {
                        navigationState.selectedContact
                    },
                    set: { navigationState.selectedContact = $0 }
                )
            )
        } detail: {
            if let contact = navigationState.selectedContact {
                ContactDetails(listItem: contact).id(contact.email)
            }
        }
    }
}

struct ContactDetails: View {
    @State private var profile: Profile? = nil
    @State private var loading: Bool = false
    @Injected(\.client) private var client
    
    let listItem: ContactListItem
    
    var body: some View {
        VStack {
            if loading {
                ProgressView()
            } else {
                if let profile = profile {
                    ProfileView(profile: profile, showActionButtons: true)
                }
            }
        }.task {
            loading = true
            profile = try? await client
                .fetchProfile(
                    address: EmailAddress(listItem.email)!,
                    force: false
                )
            loading = false
        }
    }
}

#Preview {
    ContactsTabView()
}

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
                ContactDetails(listItem: contact)
            }
        }
    }
}

struct ContactDetails: View {
    @Environment(NavigationState.self) private var navigationState
    @State private var profile: Profile? = nil
    @State private var loading: Bool = false
    @Injected(\.client) private var client
    
    let listItem: ContactListItem
    
    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else {
                if let profile = profile {
                    ProfileView(profile: profile, showActionButtons: true)
                        .navigationBarBackButtonHidden()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    navigationState.selectedContact = nil
                                } label: {
                                    Image(systemName: "chevron.backward")
                                }
                                .buttonStyle(RoundToolbarButtonStyle())
                            }
                        }
                        .toolbarBackground(.hidden, for: .navigationBar)
                }
            }
        }.task {
                if let emailAddress = EmailAddress(listItem.email) {
                    loading = true
                    profile = try? await client
                        .fetchProfile(address: emailAddress, force: false)
                    loading = false
                }
            }
    }
}

#Preview {
    ContactsTabView()
}

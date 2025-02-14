import SwiftUI
import OpenEmailCore

struct ContactsTabView: View {
    @State private var selectedContactListItem: ContactListItem?

    var body: some View {
        NavigationSplitView {
            ContactsListView(selectedContactListItem: $selectedContactListItem)
        } detail: {
            if let emailAddress = EmailAddress(selectedContactListItem?.email) {
                ProfileView(emailAddress: emailAddress, showActionButtons: true)
                    .navigationBarBackButtonHidden()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                selectedContactListItem = nil
                            } label: {
                                Image(systemName: "chevron.backward")
                            }
                            .buttonStyle(RoundToolbarButtonStyle())
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
    }
}

#Preview {
    ContactsTabView()
}

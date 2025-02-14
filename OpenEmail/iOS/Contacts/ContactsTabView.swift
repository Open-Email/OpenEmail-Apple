import SwiftUI
import OpenEmailCore

struct ContactsTabView: View {
    @State private var selectedContactListItem: ContactListItem?
    @Environment(\.dismiss) var dismiss

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
                                dismiss()
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

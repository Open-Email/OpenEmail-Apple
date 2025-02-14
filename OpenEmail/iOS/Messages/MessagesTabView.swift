import SwiftUI

struct MessagesTabView: View {
    @State private var selectedScope: SidebarScope? = .inbox
    @State private var selectedMessageID: String?
    @State var tabBarVisibility: Visibility = .visible

    var body: some View {
        NavigationSplitView(
            columnVisibility: .constant(.doubleColumn),
            preferredCompactColumn: .constant(.sidebar)
        ) {
            SidebarView(selectedScope: $selectedScope)
        } content: {
            if let selectedScope {
                MessagesListView(selectedScope: selectedScope, selectedMessageID: $selectedMessageID)
                    .navigationTitle(selectedScope.displayName)
            } else {
                EmptyListView(icon: .messagesTab, text: "No folder selected.")
            }
        } detail: {
            if let selectedMessageID, let selectedScope {
                MessageView(
                    messageID: selectedMessageID,
                    selectedScope: selectedScope,
                    selectedMessageID: $selectedMessageID
                )
                .onAppear {
                    tabBarVisibility = .hidden
                }
                .onDisappear {
                    tabBarVisibility = .visible
                }
            } else {
                Text("No selection")
                    .bold()
                    .foregroundStyle(.tertiary)
            }
        }
        .toolbar(tabBarVisibility, for: .tabBar)
        .animation(.default, value: tabBarVisibility)
    }
}

#Preview {
    MessagesTabView()
}

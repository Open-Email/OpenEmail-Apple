import SwiftUI

struct MessagesTabView: View {
    @State private var selectedMessageID: String?
    @State var tabBarVisibility: Visibility = .visible
    @Environment(NavigationState.self) private var navigationState

    var body: some View {
        NavigationSplitView(
            columnVisibility: .constant(.doubleColumn),
            preferredCompactColumn: .constant(.sidebar)
        ) {
            SidebarView()
        } content: {
            MessagesListView(selectedMessageID: $selectedMessageID)
                .navigationTitle(navigationState.selectedScope.displayName)
        } detail: {
            if let selectedMessageID {
                MessageView(
                    messageID: selectedMessageID,
                    selectedScope: navigationState.selectedScope,
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

import SwiftUI

struct MessagesTabView: View {
    @Environment(NavigationState.self) private var navigationState
    @State private var tabBarVisibility: Visibility = .visible
    @State private var messageThreadViewModel: MessageThreadViewModel = MessageThreadViewModel(messageThread: nil)
    
    var body: some View {
        NavigationSplitView(
            columnVisibility: .constant(.doubleColumn),
            preferredCompactColumn: .constant(.sidebar)
        ) {
            MessagesListView()
        } detail: {
            if let _ = messageThreadViewModel.messageThread {
                MessageThreadView(
                    messageViewModel: $messageThreadViewModel
                )
            }
        }
        .onChange(of: navigationState.selectedMessageThreads) {
            if navigationState.selectedMessageThreads.count == 1 {
                tabBarVisibility = .hidden
                messageThreadViewModel.messageThread = navigationState.selectedMessageThreads.first
            } else {
                messageThreadViewModel.messageThread = nil
                withAnimation {
                    tabBarVisibility = .visible
                }
            }
        }
        .toolbar(tabBarVisibility, for: .tabBar)
    }
}

#Preview {
    MessagesTabView()
}

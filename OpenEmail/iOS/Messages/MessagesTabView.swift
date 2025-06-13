import SwiftUI

struct MessagesTabView: View {
    @State private var selectedMessageID: String?
    @State var tabBarVisibility: Visibility = .visible
    @Environment(NavigationState.self) private var navigationState
    @State private var viewModel = ScopesSidebarViewModel()
    @State var scopeItem: ScopeSidebarItem?
    
    var body: some View {
        NavigationSplitView(
            columnVisibility: .constant(.doubleColumn),
            preferredCompactColumn: .constant(.sidebar)
        ) {
            List(viewModel.items, id: \.self, selection: $scopeItem) { item in
                Label(title: {
                    Text(item.scope.displayName)
                }, icon: {
                    Image(item.scope.imageResource)
                })
            }
            .navigationTitle("Folders")
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
        .onChange(of: scopeItem) {
            if let selectedScope = scopeItem?.scope {
                navigationState.selectedScope = selectedScope
            }
        }
        .toolbar(tabBarVisibility, for: .tabBar)
        .animation(.default, value: tabBarVisibility)
    }
}

#Preview {
    MessagesTabView()
}

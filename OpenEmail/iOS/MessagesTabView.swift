import SwiftUI

struct MessagesTabView: View {
    @State private var selectedScope: SidebarScope? = .inbox
    @State private var selectedMessageID: String?

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
                makeEmptyView()
            }
        } detail: {
            if let selectedMessageID, let selectedScope {
                MessageView(
                    messageID: selectedMessageID,
                    selectedScope: selectedScope,
                    selectedMessageID: $selectedMessageID
                )
            } else {
                Text("No selection")
                    .bold()
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func makeEmptyView() -> some View {
        VStack {
            Image(systemName: "envelope.circle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 30)
            Text("No folder selected")
                .bold()
        }
        .foregroundStyle(.tertiary)
    }
}

#Preview {
    MessagesTabView()
}

import SwiftUI
import OpenEmailPersistence
import Logging
import OpenEmailCore

struct MessagesListView: View {
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    @State private var viewModel = MessagesListViewModel()
    @State private var searchText: String = ""

    var body: some View {
        @Bindable var navigationState = navigationState

        VStack(alignment: .leading, spacing: 0) {
            SearchField(text: $searchText)
                .padding(.vertical, .Spacing.small)
                .padding(.horizontal, .Spacing.default)

            Divider()

            List(selection: $navigationState.selectedMessageIDs) {
                Section {
                    ForEach(viewModel.messages) { message in
                        MessageListItemView(
                            message: message,
                            scope: navigationState.selectedScope
                        )
                    }
                } header: {
                    Text(navigationState.selectedScope.displayName)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .padding(.Spacing.default)
                }
            }
            .listStyle(.plain)
            .contextMenu(forSelectionType: String.self) { messageIDs in
                if !messageIDs.isEmpty {
                    let allMessages = viewModel.messages
                        .filter {
                            messageIDs.contains($0.id)
                            && $0.author != registeredEmailAddress // ignore messages from self
                        }

                    if !allMessages.isEmpty {
                        if allMessages.unreadCount == 0 {
                            Button("Mark as Unread") {
                                viewModel.markAsUnread(messageIDs: messageIDs)
                            }
                        } else {
                            Button("Mark as Read") {
                                viewModel.markAsRead(messageIDs: messageIDs)
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if viewModel.messages.isEmpty && searchText.isEmpty {
                    EmptyListView(
                        icon: navigationState.selectedScope.imageResource,
                        text: "Your \(navigationState.selectedScope.displayName) message list is empty."
                    )
                }
            }
        }
        .animation(.easeInOut(duration: viewModel.messages.isEmpty ? 0 : 0.2), value: viewModel.messages)
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: navigationState.selectedMessageIDs) {
            Log.debug("selected message ids: \(navigationState.selectedMessageIDs)")
            
            if
                navigationState.selectedMessageIDs.count == 1,
                let selectedMessageID = navigationState.selectedMessageIDs.first
            {
                // Only if not read already, mark as read
                viewModel.markAsRead(messageIDs: [selectedMessageID])
            }
        }
        .onChange(of: navigationState.selectedScope) {
            navigationState.selectedMessageIDs = []
            reloadMessages()
        }
        .onChange(of: searchText) {
            reloadMessages()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didSynchronizeMessages)) { _ in
            reloadMessages()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateMessages)) { _ in
            reloadMessages()
        }
        .onAppear {
            reloadMessages()
        }
    }

    private func reloadMessages() {
        Task {
            await viewModel.reloadMessagesFromStore(searchText: searchText, scope: navigationState.selectedScope)
            updateSelectedDraftMessages()
        }
    }

    @MainActor
    private func updateSelectedDraftMessages() {
        guard navigationState.selectedScope == .drafts else { return }
        let selectedMessageIDs = Set(navigationState.selectedMessageIDs)
        let messageIds = Set(viewModel.messages.map { $0.id })
        let remainingSelectedMessageIDs = messageIds.intersection(selectedMessageIDs)
        navigationState.selectedMessageIDs = remainingSelectedMessageIDs
    }
}

#if DEBUG
#Preview {
    MessagesListView()
        .frame(width: 400, height: 500)
        .environment(NavigationState())
}

private struct PreviewContainer {
    @Injected(\.messagesStore) var messagesStore
}

#Preview("empty") {
    let container = PreviewContainer()

    MessagesListView()
        .environment(NavigationState())
        .onAppear {
            let mockStore = container.messagesStore as? MessageStoreMock
            mockStore?.stubMessages = []
        }
}
#endif

import SwiftUI
import OpenEmailPersistence
import Logging
import OpenEmailCore

struct MessagesListView: View {
    @Environment(NavigationState.self) private var navigationState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    @State private var viewModel = MessagesListViewModel()
    @Binding private var searchText: String
    
    init (searchText: Binding<String>) {
        _searchText = searchText
    }

    var body: some View {
        @Bindable var navigationState = navigationState

        List(selection: $navigationState.selectedMessageIDs) {
            
            if viewModel.messages.isEmpty && searchText.isEmpty {
                EmptyListView(
                    icon: navigationState.selectedScope.imageResource,
                    text: "Your \(navigationState.selectedScope.displayName) message list is empty."
                )
            }
            
            ForEach(viewModel.messages) { message in
                MessageListItemView(
                    message: message,
                    scope: navigationState.selectedScope
                )
                .padding(EdgeInsets(
                    top: .Spacing.xxSmall,
                    leading: .zero,
                    bottom: .Spacing.xxSmall,
                    trailing: .Spacing.xxSmall,
                    
                ))
            }
        }
        .listStyle(.automatic)
        .scrollBounceBehavior(.basedOnSize)
        .contextMenu(forSelectionType: String.self, menu: { messageIDs in
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
        }, primaryAction: { messageIDs in
            // this runs on double-click of a selected row
            if let id = messageIDs.first,
               let msg = viewModel.messages.first(where: { $0.id == id }) {
                if msg.isDraft {
                    openWindow(id: WindowIDs.compose, value: ComposeAction.editDraft(messageId: msg.id))
                } else {
                    // preview logic here
                }
            }
        })
        .animation(.easeInOut(duration: viewModel.messages.isEmpty ? 0 : 0.2), value: viewModel.messages)
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
        }.background(Color(nsColor: .controlBackgroundColor))
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
    MessagesListView(searchText: Binding<String>(
        get: { "" }, set: { _ in }
    ))
        .frame(width: 400, height: 500)
        .environment(NavigationState())
}

private struct PreviewContainer {
    @Injected(\.messagesStore) var messagesStore
}

#Preview("empty") {
    let container = PreviewContainer()

    MessagesListView(searchText: Binding<String>(
        get: { "" }, set: { _ in }
    ))
        .environment(NavigationState())
        .onAppear {
            let mockStore = container.messagesStore as? MessageStoreMock
            mockStore?.stubMessages = []
        }
}
#endif

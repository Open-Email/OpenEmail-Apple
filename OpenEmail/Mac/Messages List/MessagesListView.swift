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
                .swipeActions(edge: .trailing) {
                    AsyncButton(message.isDeleted ? "Delete Permanently" : "Delete") {
                        if message.isDeleted {
                            await viewModel.deletePermanently(messageIDs: [message.id])
                        } else {
                            await viewModel.markAsDeleted(messageIDs: [message.id], isDeleted: true)
                        }
                    }
                    .tint(.red)
                }
                
                .swipeActions(edge: .leading) {
                    if message.isDeleted {
                        AsyncButton("Restore") {
                            await viewModel.markAsDeleted(messageIDs: [message.id], isDeleted: false)
                        }
                        .tint(.accentColor)
                    } else {
                        if !message.isDraft && !message.isOutbox() {
                            Button(message.isRead ? "Mark as Unread" : "Mark as Read") {
                                if message.isRead {
                                    viewModel.markAsUnread(messageIDs: [message.id])
                                } else {
                                    viewModel.markAsRead(messageIDs: [message.id])
                                }
                            }
                            .tint(.accentColor)
                        }
                    }
                }
            }
        }
        .frame(idealWidth: 200)
        .listStyle(.automatic)
        .scrollBounceBehavior(.basedOnSize)
        .contextMenu(
            forSelectionType: String.self,
            menu: { messageIDs in
                
                if (navigationState.selectedScope == .trash) {
                    AsyncButton("Restore") {
                        await viewModel.markAsDeleted(messageIDs: messageIDs, isDeleted: false)
                        navigationState.clearSelection()
                    }
                    AsyncButton("Delete permanently") {
                        await viewModel
                            .deletePermanently(messageIDs: messageIDs)
                        navigationState.clearSelection()
                    }
                } else {
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
                        AsyncButton("Delete") {
                            await viewModel.markAsDeleted(messageIDs: messageIDs, isDeleted: true)
                            navigationState.clearSelection()
                        }
                }
            }
        },
 primaryAction: { messageIDs in
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
            viewModel.selectedScope = navigationState.selectedScope
        }
        .onChange(of: searchText) {
            viewModel.searchText = searchText
        }
        .background(Color(nsColor: .controlBackgroundColor))
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

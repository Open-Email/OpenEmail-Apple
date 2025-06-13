import SwiftUI
import OpenEmailPersistence
import OpenEmailModel
import OpenEmailCore
import Logging

struct MessagesListView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Environment(NavigationState.self) private var navigationState
    @Injected(\.syncService) private var syncService
    @Injected(\.messagesStore) private var messagesStore
    
    @Binding var selectedMessageID: String?

    @State private var viewModel = MessagesListViewModel()
    @State private var searchText: String = ""
    @State private var showsDeleteConfirmationAlert = false
    @State private var messageToDelete: Message?
    @State private var showsComposeView = false

    init(selectedMessageID: Binding<String?>) {
        _selectedMessageID = selectedMessageID
    }

    var body: some View {
        List(selection: _selectedMessageID) {
            ForEach(viewModel.messages) { message in
                MessageListItemView(message: message, scope: navigationState.selectedScope)
                    .swipeActions(edge: .trailing) {
                        trailingSwipeActionButtons(message: message)
                    }
                    .swipeActions(edge: .leading) {
                        leadingSwipeActionButtons(message: message)
                    }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText)
        .refreshable {
            await syncService.synchronize()
        }
        .animation(.default, value: viewModel.messages)
        .toolbar {
            ToolbarItem {
                Button {
                    showsComposeView = true
                } label: {
                    Image(.compose)
                }
            }
        }
        .toolbarTitleDisplayMode(.inlineLarge)
        .alert("Are you sure you want to delete this message?", isPresented: $showsDeleteConfirmationAlert) {
            Button("Cancel", role: .cancel) {}
            AsyncButton("Delete", role: .destructive) {
                do {
                    try await messageToDelete?.permentlyDelete(messageStore: messagesStore)
                    messageToDelete = nil
                } catch {
                    Log.error("Could not permanently delete message: \(error)")
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .overlay {
            if viewModel.messages.isEmpty && searchText.isEmpty {
                EmptyListView(icon: navigationState.selectedScope.imageResource, text: "Your \(navigationState.selectedScope.displayName) message list is empty.")
            }
        }
        .sheet(isPresented: $showsComposeView) {
            ComposeMessageView(action: .newMessage(id: UUID(), authorAddress: registeredEmailAddress!, readerAddress: nil))
                .interactiveDismissDisabled()
        }
        .onChange(of: selectedMessageID) {
            if let selectedMessageID {
                // Only if not read already, mark as read
                viewModel.markAsRead(messageIDs: [selectedMessageID])

                Log.debug("selected message id: \(selectedMessageID)")
            }
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
        }
    }

    @ViewBuilder
    private func trailingSwipeActionButtons(message: Message) -> some View {
        deleteButton(message: message)
    }

    @ViewBuilder
    private func leadingSwipeActionButtons(message: Message) -> some View {
        if navigationState.selectedScope == .trash {
            undeleteButton(message: message)
        }

        if message.author != registeredEmailAddress {
            readStatusButton(message: message)
        }
    }

    @ViewBuilder
    private func deleteButton(message: Message) -> some View {
        AsyncButton(role: .destructive) {
            if navigationState.selectedScope == .trash {
                messageToDelete = message
                showsDeleteConfirmationAlert = true
            } else {
                do {
                    try await messagesStore.markAsDeleted(message: message, deleted: true)
                } catch {
                    Log.error("Could not mark message as deleted: \(error)")
                }
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func undeleteButton(message: Message) -> some View {
        AsyncButton {
            do {
                try await messagesStore.markAsDeleted(message: message, deleted: false)
            } catch {
                Log.error("Could not mark message as undeleted: \(error)")
            }
        } label: {
            Label("Undelete", systemImage: "trash.slash")
        }
    }

    @ViewBuilder
    private func readStatusButton(message: Message) -> some View {
        Button {
            if message.isRead {
                viewModel.markAsUnread(messageIDs: [message.id])
            } else {
                viewModel.markAsRead(messageIDs: [message.id])
            }
        } label: {
            if message.isRead {
                Label("Unread", systemImage: "envelope.badge")
            } else {
                Label("Read", systemImage: "envelope.open.fill")
            }
        }
        .tint(.indigo)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var selectedMessageID: String?
    return NavigationStack {
        MessagesListView(selectedMessageID: $selectedMessageID)
            .navigationTitle("Inbox")
    }
}
#endif

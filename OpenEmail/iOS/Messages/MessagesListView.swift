import SwiftUI
import OpenEmailPersistence
import OpenEmailModel
import OpenEmailCore
import Logging

struct MessagesListView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Environment(NavigationState.self) private var navigationState
    @Injected(\.syncService) private var syncService
    
    @State private var viewModel = MessagesListViewModel()
    @State private var showsDeleteConfirmationAlert = false
    @State private var messageToDelete: Message?
    @State private var showsComposeView = false

    var body: some View {
        List(
            viewModel.threads,
            selection: Binding<Set<MessageThread>> (
                get: {
                    navigationState.selectedMessageThreads
                },
                set: {
                    navigationState.selectedMessageThreads = $0
                }
            )
        ) { messageThread in
            MessageListItemView(messageThread: messageThread, scope: navigationState.selectedScope)
                .tag(messageThread)
                .swipeActions(edge: .trailing) {
                    AsyncButton("Delete") {
                        await viewModel.markAsDeleted(threads: [messageThread], isDeleted: true)
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .leading) {
                    Button(messageThread.isRead ? "Mark as Unread" : "Mark as Read") {
                        if messageThread.isRead {
                            viewModel.markAsUnread(threads: [messageThread])
                        } else {
                            viewModel.markAsRead(threads: [messageThread])
                        }
                    }
                    .tint(.accentColor)
                }
        }
        .listStyle(.plain)
        .searchable(text: $viewModel.searchText)
        .refreshable {
            await syncService.synchronize()
        }
        .animation(.default, value: viewModel.threads)
        .toolbar {
            ToolbarItem {
                Button {
                    showsComposeView = true
                } label: {
                    Image(.compose)
                }
            }
        }
        .navigationTitle("Messages")
        .overlay {
            if viewModel.threads.isEmpty && viewModel.searchText.isEmpty {
                EmptyListView(icon: navigationState.selectedScope.imageResource, text: "Your \(navigationState.selectedScope.displayName) message list is empty.")
            }
        }
        .sheet(isPresented: $showsComposeView) {
            ComposeMessageView(action: .newMessage(id: UUID(), authorAddress: registeredEmailAddress!, readerAddress: nil))
                .interactiveDismissDisabled()
        }
        .onChange(of: navigationState.selectedMessageThreads) {
            viewModel
                .markAsRead(threads: navigationState.selectedMessageThreads)
        }
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

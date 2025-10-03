import SwiftUI
import OpenEmailPersistence
import Logging
import OpenEmailCore
import OpenEmailModel

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
        List(selection: Binding<Set<MessageThread>> (
            get: {
                navigationState.selectedMessageThreads
            },
            set: { navigationState.selectedMessageThreads = $0 }
        )) {
            Color.clear.frame(height: .Spacing.xxxSmall)
            ForEach(viewModel.threads) { messageThread in
                MessageListItemView(
                    messageThread: messageThread,
                    scope: navigationState.selectedScope
                )
                .tag(messageThread)
                .padding(.all, .Spacing.xxxSmall)
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
            
            Color.clear.frame(height: 100)
           
        }
        .frame(idealWidth: 200)
        .listStyle(.automatic)
        .scrollBounceBehavior(.basedOnSize)
        .onChange(of: navigationState.selectedMessageThreads) {
            viewModel
                .markAsRead(threads: navigationState.selectedMessageThreads)
        }
        .contextMenu(
            forSelectionType: MessageThread.self,
            menu: { threads in
                AsyncButton("Delete") {
                    await viewModel.markAsDeleted(threads: threads, isDeleted: true)
                    navigationState.clearSelection()
                }
            })
        .animation(.easeInOut(duration: viewModel.threads.isEmpty ? 0 : 0.2), value: viewModel.threads)
        .onChange(of: searchText) {
            viewModel.searchText = searchText
        }
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

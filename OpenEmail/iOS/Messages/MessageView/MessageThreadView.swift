import SwiftUI
import OpenEmailModel
import OpenEmailCore
import OpenEmailPersistence
import Logging
import Inspect
import MarkdownUI

@MainActor
struct MessageThreadView: View {
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Injected(\.syncService) private var syncService
    @Injected(\.messagesStore) private var messagesStore
    @Injected(\.pendingMessageStore) private var pendingMessageStore
    
    @Binding private var viewModel: MessageThreadViewModel
    
    @State private var filePickerOpen: Bool = false
    @State private var showDeleteConfirmationAlert = false
    @State private var showFilesPopover = false
    @State private var toolbarBarVisibility: Visibility = .hidden
    @State private var composeAction: ComposeAction?
    
    init(messageViewModel: Binding<MessageThreadViewModel> ) {
        _viewModel = messageViewModel
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                List {
                    MultiReadersView(readers: viewModel.messageThread?.readers ?? []).listRowSeparator(.hidden)
                    
                    ForEach(Array(viewModel.allMessages.enumerated()), id: \.element.id) { _, message in
                        if let pending = message as? PendingMessage {
                            MessageViewHolder(
                                viewModel: viewModel,
                                authoredOn: pending.formattedAuthoredOnDate,
                                authorAddress: registeredEmailAddress ?? "",
                                messageBody: pending.body ?? "",
                                attachments: nil
                            )
                            .listRowSeparator(.hidden)
                        }
                        else if let message = message as? Message {
                            MessageViewHolder(
                                viewModel: viewModel,
                                authoredOn: message.formattedAuthoredOnDate,
                                authorAddress: message.author,
                                messageBody: message.body ?? "",
                                attachments: message.attachments
                            )
                            .listRowSeparator(.hidden)
                        }
                        
                        
                    }
                    Color.clear.frame(height: 100).listRowSeparator(.hidden)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        if let lastId = viewModel.messageThread?.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .top)
                        }
                    }
                }
                .listStyle(.plain)
            }
            if #available(iOS 26.0, *) {
                QuickResponseView(
                    messageViewModel: $viewModel,
                    filePickerOpen: $filePickerOpen,
                    openComposingScreenAction: openComposingScreenAction
                )
                
                .padding(.Spacing.small)
                .glassEffect(Glass.regular, in: RoundedRectangle(cornerRadius: .CornerRadii.default))
                .padding(.Spacing.default)
            } else {
                QuickResponseView(
                    messageViewModel: $viewModel,
                    filePickerOpen: $filePickerOpen,
                    openComposingScreenAction: openComposingScreenAction
                ).clipShape(RoundedRectangle(cornerRadius: .CornerRadii.default))
                    .background {
                        RoundedRectangle(cornerRadius: .CornerRadii.default)
                            .fill(.themeViewBackground)
                            .stroke(.actionButtonOutline, lineWidth: 1)
                            .shadow(color: .actionButtonOutline, radius: 5)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: .CornerRadii.default)
                            .stroke(.actionButtonOutline, lineWidth: 1)
                    )
                
                    .padding(.Spacing.default)
            }
        }
        .sheet(isPresented: Binding<Bool> (
            get: {
                composeAction != nil
            },
            set: {
                if $0 == false {
                    composeAction = nil
                }
            }
        )) {
            ComposeMessageView(action: composeAction!)
        }
        .fileImporter(isPresented: $filePickerOpen, allowedContentTypes: [.data], allowsMultipleSelection: true) {
            do {
                let urls = try $0.get()
                viewModel.appendAttachedFiles(urls: urls)
            }
            catch {
                Log.error("error reading files: \(error)")
            }
        }
        
        .navigationTitle(viewModel.messageThread?.topic ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func openComposingScreenAction() async throws {
        
        let draftMessage: Message? = Message.draft()
        
        guard var draftMessage = draftMessage else {
            return
        }
        
        if viewModel.editSubject.trimmingCharacters(in: .whitespacesAndNewlines).isNotEmpty ||
            viewModel.editBody.trimmingCharacters(in: .whitespacesAndNewlines).isNotEmpty ||
            viewModel.attachedFileItems.isNotEmpty {
            
            draftMessage.subject = viewModel.editSubject.trimmingCharacters(in: .whitespacesAndNewlines)
            draftMessage.body = viewModel.editBody.trimmingCharacters(in: .whitespacesAndNewlines)
            
            draftMessage.draftAttachmentUrls = viewModel.attachedFileItems.map { $0.url }
            
        }
        draftMessage.readers = viewModel.messageThread?.readers ?? []
        draftMessage.isBroadcast = false
        draftMessage.subjectId = viewModel.messageThread?.subjectId ?? ""
        
        try await messagesStore.storeMessage(draftMessage)
        
        composeAction =
            .newMessage(id: UUID(), authorAddress: draftMessage.author)
    }
}



#if DEBUG
#Preview {
    let messageStore = MessageStoreMock()
    messageStore.stubMessages = [
        .makeRandom(id: "1"),
        .makeRandom(id: "2"),
        .makeRandom(id: "3")
    ]
    InjectedValues[\.messagesStore] = messageStore
    
    return MessageThreadView(
        messageViewModel: Binding<MessageThreadViewModel>(
            get: {
                MessageThreadViewModel(
                    messageThread: messageStore.stubMessages.first!
                )
            },
            set: { _ in }
        )
    )
    .frame(width: 800, height: 600)
    .background(.themeViewBackground)
    .environment(NavigationState())
}

#endif

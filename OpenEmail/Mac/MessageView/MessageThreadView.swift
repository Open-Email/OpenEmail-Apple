import SwiftUI
import OpenEmailModel
import OpenEmailCore
import OpenEmailPersistence
import Logging
import AppKit
import HighlightedTextEditor

struct MessageThreadView: View {
    @Binding private var viewModel: MessageThreadViewModel
    @State private var filePickerOpen: Bool = false
    @Environment(\.openWindow) private var openWindow
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Injected(\.attachmentsManager) var attachmentsManager: AttachmentsManager
    @Injected(\.messagesStore) private var messagesStore
    
    
    @State private var showRecallConfirmationAlert = false
    
    init(messageViewModel: Binding<MessageThreadViewModel>) {
        _viewModel = messageViewModel
    }
    var body: some View {
        Group {
            if let thread = viewModel.messageThread {
                ZStack(alignment: Alignment.bottom) {
                    ScrollViewReader { proxy in
                        List {
                            Text(thread.topic)
                                .font(.title)
                                .fontWeight(.semibold)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            
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
                            Color.clear.frame(height: 100)
                        }.onAppear {
                            DispatchQueue.main.async {
                                if let lastId = thread.messages.last?.id {
                                    proxy.scrollTo(lastId, anchor: .top)
                                }
                            }
                        }
                    }
                    
                    if #available(macOS 26.0, *) {
                        QuickResponseView(
                            messageViewModel: $viewModel,
                            filePickerOpen: $filePickerOpen,
                            openComposingScreenAction: openComposingScreenAction
                        )
                        
                        .padding(.Spacing.small)
                        .glassEffect(in: .rect(cornerRadius: .CornerRadii.default))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    } else {
                        QuickResponseView(
                            messageViewModel: $viewModel,
                            filePickerOpen: $filePickerOpen,
                            openComposingScreenAction: openComposingScreenAction
                        )
                        .background {
                            RoundedRectangle(cornerRadius: .CornerRadii.default)
                                .fill(.themeViewBackground)
                                .stroke(.actionButtonOutline, lineWidth: 1)
                                .shadow(color: .actionButtonOutline, radius: 5)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: .CornerRadii.default)
                                .fill(.themeViewBackground)
                                .stroke(.actionButtonOutline, lineWidth: 1)
                                .shadow(color: .actionButtonOutline, radius: 5)
                        )
                        .padding(.horizontal, .Spacing.default)
                        .padding(.bottom, .Spacing.default)
                    }
                }
                .background(.themeViewBackground)
            } else {
                Text("No thread selected")
            }
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
        
        openWindow(
            id: WindowIDs.compose,
            value: ComposeAction.editDraft(messageId: draftMessage.id)
        )
    }
}

#if DEBUG
#Preview {
    MessageThreadView(
        messageViewModel: Binding<MessageThreadViewModel>(
            get: {
                MessageThreadViewModel(
                    messageThread: MessageThread.makeRandom()
                )
            },
            set: { _ in }
        )
    ).environment(NavigationState())
   
}

#endif

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
    @Injected(\.syncService) private var syncService
    @Injected(\.messagesStore) private var messagesStore
    @Injected(\.pendingMessageStore) private var pendingMessageStore
    
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
                            
                            MultiReadersView(readers: viewModel.messageThread?.readers ?? [])
                            
                            ForEach(Array(viewModel.allMessages.enumerated()), id: \.element.id) { _, message in
                                if let pending = message as? PendingMessage {
                                    MessageViewHolder(
                                        viewModel: viewModel,
                                        subject: pending.displayedSubject,
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
                                        subject: message.displayedSubject,
                                        authoredOn: message.formattedAuthoredOnDate,
                                        authorAddress: message.author,
                                        messageBody: message.body ?? "",
                                        attachments: message.attachments
                                    )
                                    .listRowSeparator(.hidden)
                                }
                            }
                            Color.clear.frame(height: NSFont.preferredFont(forTextStyle: .title3).pointSize + NSFont.preferredFont(forTextStyle: .body).pointSize + 7 * .Spacing.xxSmall + 4.0 + .Spacing.xSmall + 48 + NSFont.preferredFont(forTextStyle: .footnote).pointSize)
                        }.onAppear {
                            DispatchQueue.main.async {
                                if let lastId = thread.messages.last?.id {
                                    proxy.scrollTo(lastId, anchor: .top)
                                }
                            }
                        }
                    }
                    
                    VStack(spacing: .zero) {
                        if viewModel.attachedFileItems.isNotEmpty {
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(viewModel.attachedFileItems) { attachment in
                                        ZStack(
                                            alignment: Alignment.topTrailing
                                        ) {
                                            VStack(spacing: .Spacing.xxSmall) {
                                                attachment.icon.swiftUIImage
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 48, height: 48)
                                                
                                                Text(attachment.name ?? "")
                                                    .font(.footnote)
                                            }
                                            
                                            Button {
                                                if let index = viewModel.attachedFileItems
                                                    .firstIndex(where: { $0.id.absoluteString == attachment.id.absoluteString }) {
                                                    viewModel.attachedFileItems.remove(at: index)
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                
                                            }.buttonStyle(.borderless)
                                        }
                                    }
                                }.padding(.horizontal, .Spacing.xxSmall)
                            }.padding(.vertical, .Spacing.xxSmall)
                        }
                        
                        HStack {
                            TextField("Subject:", text: $viewModel.editSubject)
                                .font(.title3)
                                .textFieldStyle(.plain)
                                
                            AsyncButton {
                                do {
                                    try await pendingMessageStore
                                        .storePendingMessage(
                                            PendingMessage(
                                                id: UUID().uuidString,
                                                authoredOn: Date(),
                                                readers: viewModel.messageThread?.readers
                                                    .filter { $0 != registeredEmailAddress } ?? [],
                                                draftAttachmentUrls: viewModel.attachedFileItems.map { $0.url },
                                                subject: viewModel.editSubject.trimmingCharacters(in: .whitespacesAndNewlines),
                                                subjectId: viewModel.messageThread?.subjectId ?? "",
                                                body: viewModel.editBody.trimmingCharacters(in: .whitespacesAndNewlines),
                                                isBroadcast: false
                                            )
                                        )
                                } catch {
                                    Log.error("Could not save pending message")
                                }
                                
                                viewModel.clear()
                                
                                Task.detached(priority: .userInitiated) {
                                    await syncService.synchronize()
                                }
                            } label: {
                                Image(systemName: "paperplane.fill")
                            }.buttonStyle(.borderless)
                                .foregroundColor(.accentColor)
                                .disabled(
                                    viewModel.editSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    viewModel.editBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                )
                        }.padding(.horizontal, .Spacing.xSmall)
                            .padding(.vertical, .Spacing.xxSmall)
                        
                        RoundedRectangle(cornerRadius: .CornerRadii.default)
                            .frame(height: 1)
                            
                            .foregroundColor(.actionButtonOutline)
                            .frame(maxWidth: .infinity)
                        
                        HStack {
                            TextField("Body:", text: $viewModel.editBody, axis: .vertical)
                                .font(.body)
                                .lineLimit(nil)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.leading)
                         
                            AsyncButton {
                                do {
                                    try await openComposingScreenAction()
                                } catch {
                                    Log.error("Could not open compose screen: \(error)")
                                }
                            } label: {
                                Text(".md")
                            }.buttonStyle(.borderless)
                            
                            Button {
                                filePickerOpen = true
                            } label: {
                                Image(systemName: "paperclip")
                                
                            }.buttonStyle(.borderless)
                        }.padding(.horizontal, .Spacing.xSmall)
                            .padding(.vertical, .Spacing.xxSmall)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: .CornerRadii.default))
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
                    
                    .padding(.horizontal, .Spacing.default)
                    .padding(.bottom, .Spacing.default)
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

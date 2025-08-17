import SwiftUI
import OpenEmailModel
import OpenEmailCore
import OpenEmailPersistence
import Logging
import MarkdownUI
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
                            
                            ForEach(
                                Array(viewModel.allMessages.enumerated()),
                                id: \.offset
                            ) {
                                index,
                                message in
                                switch message {
                                    case .normal(let msg):
                                        MessageViewHolder(
                                            viewModel: viewModel,
                                            subject: msg.displayedSubject,
                                            authoredOn: msg.formattedAuthoredOnDate,
                                            authorAddress: msg.author,
                                            messageBody: msg.body ?? ""
                                            
                                        )
                                        .listRowSeparator(.hidden)
                                    case .pending(let msg):
                                        MessageViewHolder(
                                            viewModel: viewModel,
                                            subject: msg.displayedSubject,
                                            authoredOn: msg.formattedAuthoredOnDate,
                                            authorAddress: registeredEmailAddress ?? "",
                                            messageBody: msg.body ?? ""
                                            
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
                                    viewModel.editSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
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
    
    func openComposingScreenAction() async throws {
        
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

struct MessageViewHolder: View {
    let viewModel: MessageThreadViewModel
    
    let subject: String
    let authoredOn: String
    let authorAddress: String
    let messageBody: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.large) {
            MessageHeader(
                subject: subject,
                authoredOn: authoredOn,
                authorAddress: authorAddress
            )
            HStack {
                RoundedRectangle(cornerRadius: .CornerRadii.default)
                    .frame(height: 1)
                    .foregroundColor(.actionButtonOutline)
                    .frame(maxWidth: .infinity)
                
//                AsyncButton {
//                    //TODO confirmation dialog
//                    try? await viewModel.markAsDeleted(message: message, deleted: true)
//                } label: {
//                    Image(systemName: "trash")
//                }.help("Delete message")
//                
//                RoundedRectangle(cornerRadius: .CornerRadii.default)
//                    .frame(height: 1)
//                    .foregroundColor(.actionButtonOutline)
//                    .frame(maxWidth: .infinity)
                
            }
            MessageBody(messageBody: messageBody)
        }
        .padding(.all, .Spacing.default)
        .clipShape(RoundedRectangle(cornerRadius: .CornerRadii.default))
        .overlay(
            RoundedRectangle(cornerRadius: .CornerRadii.default)
                .stroke(.actionButtonOutline, lineWidth: 1)
        )
    }
}

struct MessageBody: View {
    let messageBody: String
    
    var body: some View {
        Markdown(messageBody)
            .markdownTheme(.basic.blockquote { configuration in
                let rawMarkdown = configuration.content.renderMarkdown()
                
                let maxDepth = rawMarkdown
                    .components(separatedBy: "\n")
                    .map { line -> Int in
                        var level = 0
                        for char in line {
                            if char == " " {
                                continue
                            }
                            if (char != ">") {
                                break
                            } else {
                                level += 1
                            }
                        }
                        return level
                    }.max() ?? 0
                
                let depth = max(maxDepth, 1)
                
                let barColor: Color = if depth % 3 == 0 {
                    .red
                } else if depth % 2 == 0 {
                    .green
                } else {
                    .accent
                }
                
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(barColor)
                        .relativeFrame(width: .em(0.2))
                    
                    configuration.label
                        .relativePadding(.horizontal, length: .em(1))
                }
                .fixedSize(horizontal: false, vertical: true)
            })
            .textSelection(.enabled)
    }
}

struct MessageHeader: View {
    @Injected(\.client) var client: Client
    @Environment(NavigationState.self) private var navigationState
    @State var author: Profile?
    @State var readers: [Profile] = []
    
    let subject: String
    let authoredOn: String
    let authorAddress: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: .Spacing.xSmall) {
                Text(subject)
                    .font(.title3)
                    .textSelection(.enabled)
                    .bold()
                
                Spacer()
                
                Text(authoredOn)
                .foregroundStyle(.secondary)
                .font(.subheadline)
            }
            
            HStack(spacing: .Spacing.xxSmall) {
                ProfileImageView(emailAddress: authorAddress, size: .medium)
                
                VStack(alignment: .leading, spacing: .Spacing.xxSmall) {
                    if let author = author {
                        HStack {
                            ProfileTagView(
                                profile: author,
                                isSelected: false,
                                automaticallyShowProfileIfNotInContacts: false,
                                canRemoveReader: false,
                                showsActionButtons: true,
                            ).id(author.address)
                        }
                    }
                }
            }
        }
        .task {
            if let address = EmailAddress(authorAddress) {
                author = try? await client.fetchProfile(address: address, force: false)
            }
        }
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

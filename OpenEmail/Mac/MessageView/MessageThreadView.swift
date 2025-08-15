import SwiftUI
import OpenEmailModel
import OpenEmailCore
import OpenEmailPersistence
import Logging
import MarkdownUI
import AppKit

struct MessageThreadView: View {
    @Binding private var viewModel: MessageThreadViewModel
    @State private var filePickerOpen: Bool = false
    
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Injected(\.attachmentsManager) var attachmentsManager: AttachmentsManager
    
    @State private var showRecallConfirmationAlert = false
    
    init(messageViewModel: Binding<MessageThreadViewModel>) {
        _viewModel = messageViewModel
    }
    var body: some View {
        Group {
            if let thread = viewModel.messageThread {
                ZStack(alignment: Alignment.bottom) {
                    List {
                        Text(thread.topic)
                            .font(.title)
                            .fontWeight(.semibold)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        
                        ForEach(thread.messages, id: \.self) { message in
                            MessageViewHolder(viewModel: viewModel, message: message)
                                .listRowSeparator(.hidden)
                        }
                        Color.clear.frame(height: NSFont.preferredFont(forTextStyle: .title3).pointSize + NSFont.preferredFont(forTextStyle: .body).pointSize + 4 * .Spacing.xxSmall + 4.0 + .Spacing.xSmall)
                    }
                    VStack(spacing: .zero) {
//                        if viewModel.attachedFileItems.isNotEmpty {
//                            ScrollView(.horizontal) {
//                                HStack {
//                                }
//                            }
//                        }
                        
                        TextField("Subject:", text: $viewModel.editSubject)
                            .font(.title3)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, .Spacing.xSmall)
                            .padding(.vertical, .Spacing.xxSmall)
                        RoundedRectangle(cornerRadius: .CornerRadii.default)
                            .frame(height: 1)
                            .foregroundColor(.actionButtonOutline)
                            .frame(maxWidth: .infinity)
                        
                        HStack {
                            TextField("Body:", text: $viewModel.editBody)
                                .font(.body)
                                .textFieldStyle(.plain)
                            
                            Button {
                                filePickerOpen = true
                            } label: {
                                Image(systemName: "paperclip")
                                
                            }.buttonStyle(.borderless)
                        }.padding(.horizontal, .Spacing.xSmall)
                            .padding(.vertical, .Spacing.xxSmall)
                    }
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
}

struct MessageViewHolder: View {
    let viewModel: MessageThreadViewModel
    let message: Message
    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.large) {
            MessageHeader(message: message)
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
            MessageBody(message: message)
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
    let message: Message
    
    var body: some View {
        Markdown(message.body ?? "")
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
    
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: .Spacing.xSmall) {
                Text(message.displayedSubject)
                    .font(.title3)
                    .textSelection(.enabled)
                    .bold()
                
                Spacer()
                
                Text(
                    message.formattedAuthoredOnDate
                )
                .foregroundStyle(.secondary)
                .font(.subheadline)
            }
            
            HStack(spacing: .Spacing.xxSmall) {
                ProfileImageView(emailAddress: message.author, size: .medium)
                
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
                    
                    if (message.isBroadcast == true) {
                        HStack {
                            Image(.scopeBroadcasts)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 11)
                            Text("Broadcast")
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .font(.callout)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: .Spacing.xSmall) {
                            ReadersLabelView()
                            let deliveries = Binding<[String]>(
                                get: {
                                    message.deliveries
                                },
                                set: { _ in /* read only */ }
                            )
                            ReadersView(
                                isEditable: false,
                                readers: $readers,
                                tickedReaders: deliveries,
                                hasInvalidReader: .constant(false),
                                addingContactProgress: .constant(false),
                                showProfileType: .popover
                            )
                        }
                    }
                }
            }
        }.task {
            if let address = EmailAddress(message.author) {
                let client = client
                author = try? await client.fetchProfile(address: address, force: false)
                do {
                    let fetchedReaders = try await withThrowingTaskGroup(of: Void.self, returning: [Profile].self) { group in
                        var rv: [Profile] = []
                        message.readers.forEach { readerStr in
                            group.addTask {
                                if let address = EmailAddress(readerStr),
                                   let profile = try await client.fetchProfile(address: address, force: false) {
                                    rv.append(profile)
                                }
                            }
                        }
                        try await group.waitForAll()
                        return rv
                    }
                    readers = fetchedReaders.sorted(by: { $0.address > $1.address })
                } catch {
                    Log.error("Failed to fetch profiles: \(error)")
                }
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

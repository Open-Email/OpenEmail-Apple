import SwiftUI
import OpenEmailModel
import OpenEmailCore
import OpenEmailPersistence
import Logging
import MarkdownUI


struct MessageThreadView: View {
    @Binding private var viewModel: MessageThreadViewModel
    
    
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
                List(thread.messages, id: \.self) { message in
                    VStack(alignment: .leading, spacing: .Spacing.large) {
                        MessageHeader(message: message)
                        messageBody(message: message)
                    }
                    .padding(.Spacing.default)
                }
            }
        }
        .background(.themeViewBackground)
    }

   


    @ViewBuilder
    private func messageBody(message: Message) -> some View {
        if let text = message.body {
            Markdown(text).markdownTheme(.basic.blockquote { configuration in
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
                        //.markdownTextStyle { ForegroundColor(.secondaryText) }
                        .relativePadding(.horizontal, length: .em(1))
                }
                .fixedSize(horizontal: false, vertical: true)
            })
                
            
        } else {
            Text("Loading…").italic().disabled(true)
        }
    }
}

struct MessageHeader: View {
    @Injected(\.client) var client: Client
    @Environment(NavigationState.self) private var navigationState
    @State var author: Profile?
    @State var readers: [Profile] = []
    
    private let message: Message
    init(message: Message) {
        self.message = message
    }
    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.default) {
            HStack(spacing: .Spacing.xSmall) {
                Text(message.displayedSubject)
                    .font(.title3)
                    .textSelection(.enabled)
                    .bold()
                
                Spacer()
                
                HStack {
                    if let label = getLabel(scope: navigationState.selectedScope) {
                        Text(
                            label
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    }
                    
                    Text(
                        message.formattedAuthoredOnDate
                    )
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                }
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

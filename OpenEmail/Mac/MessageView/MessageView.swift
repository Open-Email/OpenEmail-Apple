import SwiftUI
import OpenEmailModel
import OpenEmailCore
import OpenEmailPersistence
import Logging
import MarkdownUI


struct MessageView: View {
    @Binding private var viewModel: MessageViewModel
    @State private var attachmentsListViewModel = AttachmentsListViewModel()
    
    
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Injected(\.attachmentsManager) var attachmentsManager: AttachmentsManager
    
    @State private var showRecallConfirmationAlert = false
    
    init(messageViewModel: Binding<MessageViewModel>) {
        _viewModel = messageViewModel
        attachmentsListViewModel.setMessage(message: viewModel.message)
    }
    
    var body: some View {
        Group {
            if let message = viewModel.message {
                ScrollView {
                    VStack(alignment: .leading, spacing: .Spacing.large) {
                        header(message: viewModel.message)
                        messageBody(message: message)
                        
                        if attachmentsListViewModel.items.isNotEmpty {
                            Divider()
                            AttachmentsListView(viewModel: attachmentsListViewModel)
                        }
                    }
                    .padding(.Spacing.default)
                }
            } else {
                Spacer()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.themeViewBackground)
        .blur(radius: viewModel.showProgress ? 4 : 0)
        .overlay {
            if viewModel.showProgress {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background.opacity(0.75))
            }
        }
        .onChange(of: attachmentsManager.downloadInfos) {_, infos in
            attachmentsListViewModel.refresh()
        }
        .onChange(of: viewModel.message) { _, message in
            attachmentsListViewModel.setMessage(message: message)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didSynchronizeMessages)) { _ in
            viewModel.fetchMessage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateMessages)) { _ in
            viewModel.fetchMessage()
        }
    }

    @ViewBuilder
    private func header(message: Message?) -> some View {
        VStack(alignment: .leading, spacing: .Spacing.default) {
            if let message {
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
            }
           
            HStack(spacing: .Spacing.xxSmall) {
                ProfileImageView(emailAddress: message?.author, size: .medium)

                VStack(alignment: .leading, spacing: .Spacing.xxSmall) {
                    HStack {
                        if message != nil, let profile = viewModel.authorProfile {
                            ProfileTagView(
                                profile: profile,
                                isSelected: false,
                                automaticallyShowProfileIfNotInContacts: false,
                                canRemoveReader: false,
                                showsActionButtons: true,
                            ).id(profile.address)
                        }
                    }

                    if (message?.isBroadcast == true) {
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
                                    viewModel.message?.deliveries ?? []
                                },
                                set: { _ in /* read only */ }
                            )

                            ReadersView(
                                isEditable: false,
                                readers: Binding<[Profile]>(
                                    get: {
                                        viewModel.readers
                                    },
                                    set: { _ in }
                                ),
                                tickedReaders: deliveries,
                                hasInvalidReader: .constant(false),
                                addingContactProgress: .constant(false),
                                showProfileType: .popover
                            )
                        }
                    }
                }
            }
        }
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

#if DEBUG
#Preview {
    let messageStore = MessageStoreMock()
    messageStore.stubMessages = [
        .makeRandom(id: "1"),
        .makeRandom(id: "2"),
        .makeRandom(id: "3")
    ]
    InjectedValues[\.messagesStore] = messageStore
    
    return MessageView(messageViewModel: Binding<MessageViewModel>(
        get: {
            MessageViewModel(messageID: "1")
        },
        set: { _ in }
    ))
    .frame(width: 800, height: 600)
    .background(.themeViewBackground)
    .environment(NavigationState())
}

#Preview("Draft") {
    let messageStore = MessageStoreMock()
    messageStore.stubMessages = [
        .makeRandom(id: "1", isDraft: true)
    ]
    InjectedValues[\.messagesStore] = messageStore
    
    return MessageView(messageViewModel: Binding<MessageViewModel>(
        get: {
            MessageViewModel(messageID: "1")
        },
        set: { _ in }
    ))
    .frame(width: 800, height: 600)
    .background(.themeViewBackground)
    .environment(NavigationState())
}

#Preview("Draft Broadcast") {
    let messageStore = MessageStoreMock()
    messageStore.stubMessages = [
        .makeRandom(id: "1", isDraft: true, isBroadcast: true)
    ]
    InjectedValues[\.messagesStore] = messageStore
    
    return MessageView(messageViewModel: Binding<MessageViewModel>(
        get: {
            MessageViewModel(messageID: "1")
        },
        set: { _ in }
    ))
    .frame(width: 800, height: 600)
    .background(.themeViewBackground)
    .environment(NavigationState())
}

#Preview("Empty") {
    let messageStore = MessageStoreMock()
    InjectedValues[\.messagesStore] = messageStore
    
    return MessageView(messageViewModel: Binding<MessageViewModel>(
        get: {
            MessageViewModel(messageID: "1")
        },
        set: { _ in }
    ))
    .frame(width: 800, height: 600)
    .background(.themeViewBackground)
    .environment(NavigationState())
}
#endif

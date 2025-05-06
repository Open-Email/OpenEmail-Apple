import SwiftUI
import OpenEmailModel
import OpenEmailCore
import OpenEmailPersistence
import Logging

struct MessageView: View {
    @Binding private var viewModel: MessageViewModel
    @State private var attachmentsListViewModel: AttachmentsListViewModel?
    
    
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    
    @State private var showRecallConfirmationAlert = false
    
    init(messageViewModel: Binding<MessageViewModel>) {
        _viewModel = messageViewModel
    }
    
    var body: some View {
        Group {
            if let message = viewModel.message {
                ScrollView {
                    VStack(alignment: .leading, spacing: .Spacing.large) {
                        header(message: viewModel.message)
                        messageBody(message: message)
                        
                        if let attachmentsListViewModel, !attachmentsListViewModel.items.isEmpty {
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
        .onChange(of: viewModel.message) {
            attachmentsListViewModel = nil

            guard
                let message = viewModel.message,
                let registeredEmailAddress
            else {
                return
            }

            if message.isDraft {
                if !message.draftAttachmentUrls.isEmpty {
                    attachmentsListViewModel = AttachmentsListViewModel(
                        localUserAddress: registeredEmailAddress,
                        message: message,
                        draftAttachmentUrls: message.draftAttachmentUrls
                    )
                }
            } else {
                attachmentsListViewModel = AttachmentsListViewModel(
                    localUserAddress: registeredEmailAddress,
                    message: message,
                    attachments: message.attachments
                )
            }
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
                                showProfileType: .popover
                            )
                        }
                    }
                }
            }
        }
    }

    
    @ViewBuilder
    private func recallButton(message: Message) -> some View {
        Button {
            showRecallConfirmationAlert = true
        } label: {
            Image(.scopeTrash)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(ActionButtonStyle(isImageOnly: true))
        .disabled(!viewModel.syncService.isActiveOutgoingMessageId(message.id))
        .help("Delete")
        .alert(
            "Do you want to edit or discard this message?",
            isPresented: $showRecallConfirmationAlert,
            actions: {
                
                AsyncButton("Discard", role: .destructive) {
                    do {
                        try await viewModel.recallMessage()
                        navigationState.clearSelection()
                    } catch {
                        // TODO: show error message
                        Log.error("Could not recall message: \(error)")
                    }
                }
            },
            message: {
                Text(viewModel.recallInfoMessage)
            }
        )
        .dialogSeverity(viewModel.allAttachmentsDownloaded ? .standard : .critical)
    }

    @ViewBuilder
    private func messageBody(message: Message) -> some View {
        if let text = message.body {
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .lineSpacing(.Spacing.xxxSmall)
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

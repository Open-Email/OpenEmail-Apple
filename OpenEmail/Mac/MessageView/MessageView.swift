import SwiftUI
import OpenEmailModel
import OpenEmailCore
import OpenEmailPersistence
import Logging

struct MessageView: View {
    @Binding private var viewModel: MessageViewModel
    @State private var attachmentsListViewModel: AttachmentsListViewModel?
    
    @Environment(\.openWindow) private var openWindow
    
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    
    @State private var showRecallConfirmationAlert = false
    @State private var selectedProfile: Profile?
    
    init(messageViewModel: Binding<MessageViewModel>) {
        _viewModel = messageViewModel
    }
    
    var body: some View {
        Group {
            if
                let _ = viewModel.messageID,
                let _ = registeredEmailAddress
            {
                let message = viewModel.message
                VStack(alignment: .leading, spacing: 0) {
                    header(message: message)

                    if let message {
                       
                        // body
                        ScrollView {
                            VStack(alignment: .leading, spacing: .Spacing.large) {
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
                .onTapGesture {
                    selectedProfile = nil
                }
                .blur(radius: viewModel.showProgress ? 4 : 0)
                .overlay {
                    if viewModel.showProgress {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.background.opacity(0.75))
                    }
                }
                .overlay(alignment: .trailing) {
                    if let selectedProfile {
                        ProfileView(
                            profile: selectedProfile,
                            showActionButtons: false,
                            verticalLayout: true,
                            onClose: {
                                self.selectedProfile = nil
                            }
                        ).id(selectedProfile.address.address)
                        .frame(width: 320)
                        .frame(maxHeight: .infinity)
                    }
                }
            } else {
                Text("Select a message")
                    .fontWeight(.medium)
                    .padding(.horizontal, .Spacing.small)
                    .padding(.vertical, .Spacing.xxSmall)
                    .background {
                        Capsule()
                            .fill(.themeBackground)
                    }
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
        .onChange(of: navigationState.selectedMessageIDs) {
            selectedProfile = nil
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
        VStack(alignment: .leading, spacing: .Spacing.large) {
            HStack(spacing: .Spacing.xSmall) {
                Text(message?.displayedSubject ?? "–")
                    .font(.title2)
                    .textSelection(.enabled)
                    .bold()

                if let message {
                    MessageTypeBadge(scope: navigationState.selectedScope)

                    Spacer()

                    (Text(message.authoredOn, style: .date) + Text(" at ") + Text(message.authoredOn, style: .time))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: .Spacing.small) {
                ProfileImageView(emailAddress: message?.author)
                    .onTapGesture {
                        selectedProfile = viewModel.authorProfile
                    }

                VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                    HStack {
                        if message != nil, let profile = viewModel.authorProfile {
                            ProfileTagView(
                                profile: profile,
                                isSelected: false,
                                automaticallyShowProfileIfNotInContacts: false,
                                canRemoveReader: false,
                                showsActionButtons: true,
                                onShowProfile: { profile in
                                    selectedProfile = profile
                                }
                            ).id(profile.address)
                        }
                    }

                    if message?.isBroadcast == false {
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
                                showProfileType: .callback(onShowProfile: { profile in
                                    selectedProfile = profile
                                })
                            )
                        }
                        .padding(.bottom, 8)
                    } else {
                        HStack {
                            HStack(spacing: 2) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                Text("Broadcast".uppercased())
                                    .bold()
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .padding(.Spacing.default)
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
            Text(text).textSelection(.enabled)
                .lineSpacing(5)
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

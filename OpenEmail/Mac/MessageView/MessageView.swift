import SwiftUI
import OpenEmailModel
import OpenEmailCore
import OpenEmailPersistence
import Logging

@MainActor
struct MessageView: View {
    @State private var viewModel: MessageViewModel
    @State private var attachmentsListViewModel: AttachmentsListViewModel?

    @Environment(\.openWindow) private var openWindow

    @MainActor
    @Environment(NavigationState.self) private var navigationState
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    @State private var showDeleteConfirmationAlert = false
    @State private var showRecallConfirmationAlert = false

    @Binding private var selectedMessageProfileAddress: EmailAddress?

    private let selectedProfileViewModel: ProfileViewModel?

    init(messageID: String?, selectedProfileViewModel: ProfileViewModel?, selectedMessageProfileAddress: Binding<EmailAddress?>) {
        viewModel = MessageViewModel(messageID: messageID)
        self.selectedProfileViewModel = selectedProfileViewModel
        _selectedMessageProfileAddress = selectedMessageProfileAddress
        _selectedMessageProfileAddress = selectedMessageProfileAddress
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
                        // action buttons
                        ZStack {
                            Divider()

                            HStack {
                                Spacer()
                                if message.isDraft {
                                    draftActionButtons(message: message)
                                        .fixedSize()
                                } else {
                                    actionButtons(message: message)
                                }
                            }
                            .buttonStyle(ActionButtonStyle())
                            .padding(.horizontal, .Spacing.default)
                        }
                        .background(.themeViewBackground)

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
                .blur(radius: viewModel.showProgress ? 4 : 0)
                .overlay {
                    if viewModel.showProgress {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.background.opacity(0.75))
                    }
                }
                .overlay(alignment: .trailing) {
                    if let selectedProfileViewModel {
                        ProfileView(
                            viewModel: selectedProfileViewModel,
                            showActionButtons: false,
                            verticalLayout: true,
                            onClose: {
                                self.selectedMessageProfileAddress = nil
                            }
                        )
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
            viewModel.messageID = navigationState.selectedMessageIDs.first
            selectedMessageProfileAddress = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .didSynchronizeMessages)) { _ in
            viewModel.doFetchMessage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateMessages)) { _ in
            viewModel.doFetchMessage()
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
                    messageTypeBadge(message: message)

                    Spacer()

                    (Text(message.authoredOn, style: .date) + Text(" at ") + Text(message.authoredOn, style: .time))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: .Spacing.small) {
                ProfileImageView(emailAddress: message?.author)
                    .onTapGesture {
                        selectedMessageProfileAddress = EmailAddress(message?.author)
                    }

                VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                    HStack {
                        if message != nil {
                            if let authorName = viewModel.authorProfile?[.name] {
                                Text(authorName)
                                    .fontWeight(.semibold)
                            }

                            ProfileTagView(
                                emailAddress: Binding(get: {
                                    viewModel.message?.author
                                }, set: { _ in }),
                                isSelected: false,
                                configuration: .init(
                                    automaticallyShowProfileIfNotInContacts: false,
                                    canRemoveReader: false,
                                    showsActionButtons: true,
                                    onShowProfile: { _ in
                                        selectedMessageProfileAddress = EmailAddress(message?.author)
                                    })
                            )
                        } else {
                            ProfileTagView(
                                emailAddress: .constant("placeholder"),
                                isSelected: false,
                                configuration: .init(
                                    automaticallyShowProfileIfNotInContacts: false,
                                    canRemoveReader: false,
                                    showsActionButtons: true)
                            )
                            .redacted(reason: .placeholder)
                            .disabled(true)
                        }
                    }

                    if message?.isBroadcast == false {
                        HStack(alignment: .firstTextBaseline, spacing: .Spacing.xSmall) {
                            HStack(spacing: .Spacing.xxxSmall) {
                                Image(.readers)
                                Text("Readers:")
                            }
                            .foregroundStyle(.secondary)

                            let readersBinding = Binding<[EmailAddress]>(
                                get: {
                                    viewModel.message?.readers.compactMap {
                                        EmailAddress($0)
                                    } ?? []
                                },
                                set: { _ in /* read only */ }
                            )
                            let deliveries = Binding<[String]>(
                                get: {
                                    viewModel.message?.deliveries ?? []
                                },
                                set: { _ in /* read only */ }
                            )

                            ReadersView(
                                isEditable: false,
                                readers: readersBinding,
                                tickedReaders: deliveries,
                                hasInvalidReader: .constant(false),
                                prefixLabel: nil,
                                showProfileType: .callback(onShowProfile: { address in
                                    selectedMessageProfileAddress = EmailAddress(address)
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
    private func actionButtons(message: Message) -> some View {
        if message.readers.count > 1 {
            Button {
                openWindow(
                    id: WindowIDs.compose,
                    value: ComposeAction.replyAll(
                        id: UUID(),
                        authorAddress: registeredEmailAddress!,
                        messageId: message.id,
                        quotedText: message.body
                    )
                )
            } label: {
                HStack(spacing: .Spacing.xxSmall) {
                    Image(.replyAll)
                    Text("Reply All")
                }
            }
        }
        
        Button {
            guard let registeredEmailAddress else { return }
            openWindow(
                id: WindowIDs.compose,
                value: ComposeAction.reply(
                    id: UUID(),
                    authorAddress: registeredEmailAddress,
                    messageId: message.id,
                    quotedText: message.body
                )
            )
        } label: {
            HStack(spacing: .Spacing.xxSmall) {
                Image(.reply)
                Text("Reply")
            }
        }

        Button {
            openWindow(
                id: WindowIDs.compose,
                value: ComposeAction.forward(
                    id: UUID(),
                    authorAddress: registeredEmailAddress!,
                    messageId: message.id
                )
            )
        } label: {
            HStack(spacing: .Spacing.xxSmall) {
                Image(.forward)
                Text("Forward")
            }
        }

        if navigationState.selectedScope == .outbox {
            recallButton(message: message)
        } else {
            if navigationState.selectedScope == .trash && message.author != registeredEmailAddress {
                undeleteButton()
            }

            deleteButton(message: message)
        }
    }

    @ViewBuilder
    private func draftActionButtons(message: Message) -> some View {
        if message.deletedAt == nil {
            Button {
                editDraft()
            } label: {
                Image(.editDraft)
            }
            .buttonStyle(ActionButtonStyle(isImageOnly: true))
            .help("Edit")
        }

        if navigationState.selectedScope == .trash {
            undeleteButton()
        }

        deleteButton(message: message)
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
                AsyncButton("Edit") {
                    do {
                        if let draftMessage = try await viewModel.convertToDraft() {
                            try await viewModel.recallMessage()

                            DispatchQueue.main.async {
                                navigationState.selectedScope = .drafts

                                DispatchQueue.main.async {
                                    navigationState.selectedMessageIDs = [draftMessage.id]
                                }

                                openWindow(
                                    id: WindowIDs.compose,
                                    value: ComposeAction.editDraft(messageId: draftMessage.id)
                                )
                            }
                        }
                    } catch {
                        // TODO: show error message
                        Log.error("Could not convert to draft: \(error)")
                    }
                }

                AsyncButton("Discard", role: .destructive) {
                    do {
                        try await viewModel.recallMessage()
                        navigationState.selectedMessageIDs = []
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
    private func undeleteButton() -> some View {
        AsyncButton {
            do {
                try await viewModel.markAsDeleted(false)
                navigationState.selectedMessageIDs = []
            } catch {
                Log.error("Could not mark message as undeleted: \(error)")
            }
        } label: {
            Image(.undelete)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(ActionButtonStyle(isImageOnly: true))
        .help("Undelete message")

        Divider()
    }

    @ViewBuilder
    private func deleteButton(message: Message) -> some View {
        AsyncButton {
            if navigationState.selectedScope == .trash {
                showDeleteConfirmationAlert = true
            } else {
                do {
                    try await viewModel.markAsDeleted(true)
                    navigationState.selectedMessageIDs = []
                } catch {
                    Log.error("Could not mark message as deleted: \(error)")
                }
            }
        } label: {
            Image(.scopeTrash)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(ActionButtonStyle(isImageOnly: true))
        .help(message.isDraft ? "Delete draft" : "Delete message")
        .alert("Are you sure you want to delete this message?", isPresented: $showDeleteConfirmationAlert) {
            Button("Cancel", role: .cancel) {}
            AsyncButton("Delete", role: .destructive) {
                await permanentlyDelete()
            }
        } message: {
            Text("This action cannot be undone.")
        }
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

    @ViewBuilder
    private func messageTypeBadge(message: Message) -> some View {
        let text: String? = {
            switch navigationState.selectedScope {
            case .broadcasts: "Broadcast"
            case .inbox: "Incoming"
            case .outbox: "Outgoing"
            case .drafts: "Draft"
            case .trash: nil
            case .contacts: nil
            }
        }()

        if let text {
            Text(text)
                .fontWeight(.semibold)
                .padding(.horizontal, .Spacing.xSmall)
                .padding(.vertical, .Spacing.xxSmall)
                .background {
                    RoundedRectangle(cornerRadius: .CornerRadii.small)
                        .fill(.themeBadgeBackground)
                }
        } else {
            EmptyView()
        }
    }

    private func editDraft() {
        guard let messageID = viewModel.messageID else { return }

        openWindow(
            id: WindowIDs.compose,
            value: ComposeAction.editDraft(messageId: messageID)
        )
    }

    private func permanentlyDelete() async {
        do {
            // TODO: Should the message also be recalled if outgoing and on server?
            try await viewModel.permanentlyDeleteMessage()
            navigationState.selectedMessageIDs = []
        } catch {
            Log.error("Could not delete message: \(error)")
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

    return MessageView(messageID: "1", selectedProfileViewModel: nil, selectedMessageProfileAddress: .constant(nil))
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

    return MessageView(messageID: "1", selectedProfileViewModel: nil, selectedMessageProfileAddress: .constant(nil))
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

    return MessageView(messageID: "1", selectedProfileViewModel: nil, selectedMessageProfileAddress: .constant(nil))
        .frame(width: 800, height: 600)
        .background(.themeViewBackground)
        .environment(NavigationState())
}

#Preview("Empty") {
    let messageStore = MessageStoreMock()
    InjectedValues[\.messagesStore] = messageStore

    return MessageView(messageID: nil, selectedProfileViewModel: nil, selectedMessageProfileAddress: .constant(nil))
        .frame(width: 800, height: 600)
        .background(.themeViewBackground)
        .environment(NavigationState())
}
#endif

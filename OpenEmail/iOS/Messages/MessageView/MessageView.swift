import SwiftUI
import OpenEmailModel
import OpenEmailCore
import OpenEmailPersistence
import Logging
import Inspect

@MainActor
struct MessageView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?

    @Binding var selectedMessageID: String?
    let selectedScope: SidebarScope

    @State private var viewModel: MessageViewModel
    @State private var attachmentsListViewModel: AttachmentsListViewModel?

    @State private var showDeleteConfirmationAlert = false
    @State private var showRecallConfirmationAlert = false
    @State private var showAuthorProfilePopover = false
    @State private var showFilesPopover = false
    @State private var toolbarBarVisibility: Visibility = .hidden
    @State private var composeAction: ComposeAction?

    init(messageID: String, selectedScope: SidebarScope, selectedMessageID: Binding<String?>) {
        viewModel = MessageViewModel(messageID: messageID)
        self.selectedScope = selectedScope
        _selectedMessageID = selectedMessageID
    }

    var body: some View {
        Group {
            if let _ = viewModel.messageID {
                if let message = viewModel.message {
                    messageView(message: message)
                        .alert("Are you sure you want to delete this message?", isPresented: $showDeleteConfirmationAlert) {
                            Button("Cancel", role: .cancel) {}
                            AsyncButton("Delete", role: .destructive) {
                                await permanentlyDelete()
                            }
                        } message: {
                            Text("This action cannot be undone.")
                        }
                        .navigationBarTitleDisplayMode(.inline)
                }
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
    }

    @ToolbarContentBuilder
    private func bottomToolbarContent(message: Message) -> some ToolbarContent {
        if message.isDraft {
            ToolbarItemGroup(placement: .bottomBar) {
                deleteButton(message: message)

                Button {
                    composeAction = .editDraft(messageId: message.id)
                } label: {
                    Image(.compose)
                }
            }
        } else {
            ToolbarItemGroup(placement: .bottomBar) {
                if selectedScope == .outbox {
                    recallButton(message: message)
                } else {
                    if selectedScope == .trash && message.author != registeredEmailAddress {
                        undeleteButton
                        Spacer()
                        deleteButton(message: message)
                    } else {
                        deleteButton(message: message)
                    }
                }

                Spacer()
                Button("Reply", image: .reply) {
                    guard let registeredEmailAddress else { return }
                    composeAction = .reply(
                        id: UUID(),
                        authorAddress: registeredEmailAddress,
                        messageId: message.id,
                        quotedText: message.body
                    )
                }

                if message.readers.count > 1 {
                    Spacer()
                    Button("Reply all", image: .replyAll) {
                        guard let registeredEmailAddress else { return }
                        composeAction = .replyAll(
                            id: UUID(),
                            authorAddress: registeredEmailAddress,
                            messageId: message.id,
                            quotedText: message.body
                        )
                    }
                }

                Spacer()
                Button("Forward", image: .forward) {
                    guard let registeredEmailAddress else { return }
                    composeAction = .forward(
                        id: UUID(),
                        authorAddress: registeredEmailAddress,
                        messageId: message.id
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func recallButton(message: Message) -> some View {
        Button("Delete", image: .trash) {
            showRecallConfirmationAlert = true
        }
        .disabled(!viewModel.syncService.isActiveOutgoingMessageId(message.id))
        .alert(
            "Do you want to edit or discard this message?",
            isPresented: $showRecallConfirmationAlert,
            actions: {
                AsyncButton("Edit") {
                    do {
                        if let draftMessage = try await viewModel.convertToDraft() {
                            try await viewModel.recallMessage()
                            composeAction = .editDraft(messageId: draftMessage.id)
                        }
                    } catch {
                        // TODO: show error message
                        Log.error("Could not convert to draft: \(error)")
                    }
                }

                AsyncButton("Discard", role: .destructive) {
                    await recallMessage()
                    selectedMessageID = nil
                }
            },
            message: {
                Text(viewModel.recallInfoMessage)
            }
        )
    }

    @ViewBuilder
    private var undeleteButton: some View {
        AsyncButton {
            do {
                try await viewModel.markAsDeleted(false)
                selectedMessageID = nil
            } catch {
                Log.error("Could not mark message as undeleted: \(error)")
            }
        } label: {
            Image(.undelete)
        }
        .help("Undelete")
    }

    @ViewBuilder
    private func deleteButton(message: Message) -> some View {
        AsyncButton(role: .destructive) {
            if selectedScope == .trash {
                showDeleteConfirmationAlert = true
            } else {
                do {
                    try await viewModel.markAsDeleted(true)
                    selectedMessageID = nil
                } catch {
                    Log.error("Could not mark message as deleted: \(error)")
                }
            }
        } label: {
            Image(.trash)
        }
        .help("Delete")
    }

    @ViewBuilder
    private func messageView(message: Message) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                header(message: message)

                Divider()

                readers(message: message)

                Divider()

                StaticTextEditorView(string: .constant(message.body ?? ""))

                if let attachmentsListViewModel, !attachmentsListViewModel.items.isEmpty {
                    Divider()
                    AttachmentsListView(viewModel: attachmentsListViewModel)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .toolbar {
            bottomToolbarContent(message: message)
        }
        .toolbarBackground(.thinMaterial, for: .bottomBar)
        .toolbar(toolbarBarVisibility, for: .bottomBar)
        .modify {
            if #available(iOS 18.0, *) {
                $0.toolbarBackgroundVisibility(.visible, for: .bottomBar)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                toolbarBarVisibility = .visible
            }
        }
        .animation(.default, value: toolbarBarVisibility)
        .sheet(isPresented: composeSheetBinding) {
            if let composeAction {
                ComposeMessageView(action: composeAction) { result in
                    switch composeAction {
                    case .editDraft: handleCloseDraft(result: result)
                    default: break
                    }
                }
            }
        }
    }

    private func handleCloseDraft(result: ComposeResult) {
        switch result {
        case .sent:
            // After sending a draft, the draft message is deleted.
            // Setting selectedMessageID to nil will navigate back to the drafts list.
            selectedMessageID = nil
        case .cancel:
            // A draft may have updated data, so reload the draft message
            viewModel.fetchMessage()
        }
    }

    private var composeSheetBinding: Binding<Bool> {
        .init(
            get: { composeAction != nil
            },
            set: {
                if $0 == false {
                    composeAction = nil
                }
            })
    }

    @ViewBuilder
    private func header(message: Message) -> some View {
        VStack(alignment: .leading, spacing: .Spacing.large) {
            HStack(alignment: .top, spacing: .Spacing.small) {
                Text(message.subject)
                    .font(.title2)
                    .textSelection(.enabled)

                MessageTypeBadge(scope: selectedScope)
            }

            HStack(alignment: .top) {
                authorProfileImage(address: message.author)
                authorInfo(message: message)
                Spacer()
                sendDateLine(message: message)
            }
        }
    }

    @ViewBuilder
    private func authorProfileImage(address: String) -> some View {
        ProfileImageView(emailAddress: address, size: .medium)
            .onTapGesture {
                showAuthorProfilePopover = true
            }
            .popover(isPresented: $showAuthorProfilePopover) {
                if let emailAddress = EmailAddress(address) {
                    NavigationStack {
                        ProfileView(emailAddress: emailAddress, showActionButtons: false)
                            .profilePopoverToolbar {
                                showAuthorProfilePopover = false
                            }
                    }
                }
            }
    }

    @ViewBuilder
    private func authorInfo(message: Message) -> some View {
        if message.isBroadcast {
            HStack {
                HStack(spacing: 2) {
                    Image(.scopeBroadcasts)
                    Text("Broadcast")
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if let profile = viewModel.authorProfile {
                    Text(profile.name).font(.headline)
                    Text(message.author)
                } else {
                    Text(message.author).font(.headline)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func sendDateLine(message: Message) -> some View {
        Text(message.formattedAuthoredOnDate)
            .font(.subheadline)
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private func readers(message: Message) -> some View {
        VStack(alignment: .leading, spacing: .Spacing.small) {
            ReadersView(
                isEditable: false,
                readers: viewModel.readers,
                tickedReaders: .constant(viewModel.message?.deliveries ?? []),
                hasInvalidReader: .constant(false)
            )
        }
    }

    private func permanentlyDelete() async {
        do {
            // TODO: Should the message also be recalled if outgoing and on server?
            try await viewModel.permanentlyDeleteMessage()
            selectedMessageID = nil
        } catch {
            Log.error("Could not delete message: \(error)")
        }
    }

    private func recallMessage() async {
        do {
            try await viewModel.recallMessage()
            selectedMessageID = nil
        } catch {
            Log.error("Could not recall message: \(error)")
        }
    }
}

private struct StaticTextEditorView: View {
    @Binding var string: String
    @State var textEditorHeight: CGFloat = 20
    @State var font: Font = .system(.body)

    private let marginOffset: CGFloat = 5

    var body: some View {
        ZStack(alignment: .leading) {
            Text(string)
                .font(font)
                .foregroundColor(.clear)
                .padding(marginOffset)
                .background(GeometryReader {
                    Color.clear.preference(key: ViewHeightKey.self, value: $0.frame(in: .local).size.height + 2 * marginOffset)
                })

            TextEditor(text: $string)
                .inspect {
                    $0.isEditable = false
                }
                .font(font)
                .frame(height: max(0, textEditorHeight))
                .scrollDisabled(true)
        }
        .onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
        .padding(-marginOffset)
    }
}


struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = value + nextValue()
    }
}

#if DEBUG
#Preview {
    let messageStore = MessageStoreMock()
    messageStore.stubMessages = [
        .makeRandom(
            id: "1",
            subject: "This is a long subject that will spread to multiple lines",
            body: """
            Lorem ipsum dolor sit amet, sea pertinax pertinacia appellantur in, est ad esse assentior mediocritatem, magna populo menandri cum te. Vel augue menandri eu, at integre appareat splendide duo. Est ne tollit ullamcorper, eu pro falli diceret perpetua, sea ferri numquam legendos ut. Diceret suscipiantur at nec, his ei nulla mentitum efficiantur. Errem saepe ei vis.
            """
        ),
    ]
    InjectedValues[\.messagesStore] = messageStore

    return NavigationStack {
        MessageView(messageID: "1", selectedScope: .inbox, selectedMessageID: .constant("1"))
    }
}

#Preview("Short text") {
    let messageStore = MessageStoreMock()
    messageStore.stubMessages = [
        .makeRandom(id: "1", subject: "Hello", body: "Hello"),
    ]
    InjectedValues[\.messagesStore] = messageStore

    return NavigationStack {
        MessageView(messageID: "1", selectedScope: .inbox, selectedMessageID: .constant("1"))
    }
}

#Preview("Draft") {
    let messageStore = MessageStoreMock()
    messageStore.stubMessages = [
        .makeRandom(id: "1", isDraft: true)
    ]
    InjectedValues[\.messagesStore] = messageStore

    return NavigationStack {
        MessageView(messageID: "1", selectedScope: .inbox, selectedMessageID: .constant("1"))
    }
}

#Preview("Draft Broadcast") {
    let messageStore = MessageStoreMock()
    messageStore.stubMessages = [
        .makeRandom(id: "1", isDraft: true, isBroadcast: true)
    ]
    InjectedValues[\.messagesStore] = messageStore

    return NavigationStack {
        MessageView(messageID: "1", selectedScope: .inbox, selectedMessageID: .constant("1"))
    }
}
#endif

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
                        .popover(isPresented: $showFilesPopover) {
                            if let attachmentsListViewModel {
                                NavigationView {
                                    AttachmentsListView(viewModel: attachmentsListViewModel)
                                        .navigationTitle("Attachments")
                                        .navigationBarTitleDisplayMode(.inline)
                                        .toolbar {
                                            Button("Close", role: .cancel) {
                                                showFilesPopover = false
                                            }
                                        }
                                }
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Menu {
                                    // TODO: draft action buttons
                                    actionButtons(message: message)
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }

                            if message.hasFiles {
                                ToolbarItem {
                                    Button {
                                        showFilesPopover = true
                                    } label: {
                                        Image(systemName: "paperclip")
                                    }
                                }
                            }
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

    @ViewBuilder
    private func actionButtons(message: Message) -> some View {
        Button {
            guard let registeredEmailAddress else { return }
            // TODO
        } label: {
            Image(systemName: "arrowshape.turn.up.left")
            Text("Reply")
        }

        if message.readers.count > 1 {
            Button {
                // TODO
            } label: {
                Image(systemName: "arrowshape.turn.up.left.2")
                Text("Reply all")
            }
        }

        Button {
            // TODO
        } label: {
            Image(systemName: "arrowshape.forward")
            Text("Forward")
        }

        if selectedScope == .outbox {
            recallButton(message: message)
        } else {
            if selectedScope == .trash && message.author != registeredEmailAddress {
                undeleteButton
            }

            deleteButton(message: message)
        }
    }

    @ViewBuilder
    private func recallButton(message: Message) -> some View {
        Button {
            showRecallConfirmationAlert = true
        } label: {
            Image(systemName: "trash")
            Text("Delete")
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

                            selectedMessageID = nil

                            // TODO: open modal with draft editor
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
            Image(systemName: "trash.slash")
            Text("Undelete")
        }
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
            Image(systemName: "trash")
            Text("Delete")
        }
    }

    @ViewBuilder
    private func messageView(message: Message) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(message: message)

                Divider()

                VStack(spacing: 0) {
                    StaticTextEditorView(string: .constant(message.subject), font: .title2.bold())
                    StaticTextEditorView(string: .constant(message.body ?? ""))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func header(message: Message) -> some View {
        HStack(alignment: .top) {
            authorProfileImage(address: message.author)
            authorAndReadersLine(message: message)
        }
    }

    @ViewBuilder
    private func authorProfileImage(address: String) -> some View {
        ProfileImageView(emailAddress: address, size: 40)
            .onTapGesture {
                showAuthorProfilePopover = true
            }
            .popover(isPresented: $showAuthorProfilePopover) {
                if let emailAddress = EmailAddress(address) {
                    NavigationStack {
                        ProfileView(emailAddress: emailAddress, showActionButtons: false)
                            .toolbar {
                                Button(role: .cancel) {
                                    showAuthorProfilePopover = false
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .foregroundStyle(.white)
                            }
                    }
                }
            }
    }

    @ViewBuilder
    private func authorAndReadersLine(message: Message) -> some View {
        if message.isBroadcast {
            HStack {
                HStack(spacing: 2) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                    Text("Broadcast".uppercased())
                        .bold()
                    Spacer()
                    sendDateLine(message: message)
                }
            }
        } else {
            VStack(alignment: .leading) {
                HStack {
                    Text(message.author)
                        .font(.headline)
                    Spacer()
                    sendDateLine(message: message)
                }

                HStack(alignment: .top) {
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
                        prefixLabel: "To:"
                    )
                }
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private func sendDateLine(message: Message) -> some View {
        Text(message.formattedAuthoredOnDate)
            .font(.subheadline)
            .foregroundStyle(.tertiary)
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

    var body: some View {
        ZStack(alignment: .leading) {
            Text(string)
                .font(font)
                .foregroundColor(.clear)
                .padding(5)
                .background(GeometryReader {
                    Color.clear.preference(key: ViewHeightKey.self,
                                           value: $0.frame(in: .local).size.height)
                })

            TextEditor(text: $string)
                .inspect {
                    $0.isEditable = false
                    $0.textContainerInset = .zero
                    $0.contentInset = .init(top: 0, left: -5, bottom: 0, right: -5)
                }
                .font(font)
                .frame(height: max(0, textEditorHeight))
                .scrollDisabled(true)
        }
        .onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
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
        .makeRandom(id: "1", subject: "This is a long subject that will spread to multiple lines", body: "Hello"),
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

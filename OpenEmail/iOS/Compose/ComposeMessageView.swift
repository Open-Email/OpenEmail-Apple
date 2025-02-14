import SwiftUI
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel
import Logging

struct ComposeMessageView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @AppStorage(UserDefaultsKeys.profileName) private var profileName: String?

    @State private var viewModel: ComposeMessageViewModel
    @FocusState private var isTextEditorFocused: Bool
    @FocusState private var isReadersFocused: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var hasInvalidReader = false
    @State private var showsAttachments: Bool = false

    @State private var showsError = false
    @State private var error: Error?

    @State private var pendingEmailAddress: String = ""

    private var showsSuggestions: Bool {
        isReadersFocused && !viewModel.contactSuggestions.isEmpty
    }

    init(action: ComposeAction) {
        viewModel = ComposeMessageViewModel(action: action)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if viewModel.canBroadcast {
                    Toggle("Broadcast", isOn: $viewModel.isBroadcast)
                        .font(.subheadline)
                        .tint(Color.accentColor)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, .Spacing.xSmall)
                    Divider()
                }

                if !viewModel.isBroadcast {
                    ReadersView(isEditable: true, readers: $viewModel.readers, tickedReaders: .constant([]), hasInvalidReader: $hasInvalidReader, pendingText: $pendingEmailAddress)
                        .focused($isReadersFocused)

                    Divider()

                    if showsSuggestions {
                        suggestions
                    }
                } else {
                    TokenTextField(
                        tokens: .constant([AllContactsToken.empty(isSelected: false)]),
                        isEditable: false,
                        label: {
                            ReadersLabelView()
                        }
                    )

                    Divider()
                }

                if !showsSuggestions {
                    HStack(spacing: .Spacing.xSmall) {
                        Text("Subject:")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        TextField("", text: $viewModel.subject)
                    }
                    .padding(.vertical, .Spacing.xSmall)

                    Divider()

                    TextEditor(text: $viewModel.fullText)
                        .focused($isTextEditorFocused)
                        .font(.body)
                        .listRowSeparator(.hidden, edges: .bottom)
                        .id("body")
                        .padding(.horizontal, -4)
                }
            }
            .padding(.horizontal)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // TODO: ask if user wants to delete or save the draft
                    AsyncButton("Cancel") {
                        await viewModel.deleteDraft()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        showsAttachments = true
                    } label: {
                        Image(systemName: "paperclip")
                    }
                    .overlay(alignment: .topTrailing) {
                        attachmentsCountBadge
                    }
                    .help("Add files to the message")
                    .popover(isPresented: $showsAttachments) {
                        ComposeAttachmentsListView(attachedFileItems: $viewModel.attachedFileItems, messageId: viewModel.draftMessage?.id ?? "")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    AsyncButton {
                        do {
                            try await viewModel.send()
                            dismiss()
                        } catch {
                            guard !(error is CancellationError) else {
                                return
                            }

                            showsError = true
                            self.error = error
                            Log.error("Error sending message: \(error)")
                        }
                    } label: {
                        Text("Send")
                    }
                    .buttonStyle(SendButtonStyle())
                    .help("Compose new message")
                    .disabled(hasInvalidReader || !viewModel.isSendButtonEnabled)
                }
            }
            .navigationTitle("New Message")
            .alert("Could not send message", isPresented: $showsError, actions: {
            }, message: {
                if let error {
                    Text("Underlying error: \(String(describing: error))")
                }
            })
            .overlay {
                if viewModel.isSending {
                    Color(uiColor: .systemBackground).opacity(0.7)

                    VStack(spacing: 8) {
                        ProgressView()

                        if !viewModel.attachedFileItems.isEmpty {
                            ProgressView(value: viewModel.uploadProgress)
                                .progressViewStyle(.linear)
                                .frame(width: 200)
                                .tint(.white)

                            Button("Cancel") {
                                viewModel.cancelSending()
                            }
                        }
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.updateIsSendButtonEnabled()

                    if !viewModel.readers.isEmpty {
                        isTextEditorFocused = true
                    } else if case .forward = viewModel.action {
                        isReadersFocused = true
                    }
                }
            }
            .onChange(of: pendingEmailAddress) {
                Task {
                    await viewModel.loadContactSuggestions(for: pendingEmailAddress)
                }
            }
            .onChange(of: viewModel.attachedFileItems) {
                viewModel.updateDraft()
            }
        }
    }

    @ViewBuilder
    private var attachmentsCountBadge: some View {
        let count = viewModel.attachedFileItems.count

        if count == 0 {
            EmptyView()
        } else {

            HStack(spacing: 0) {
                Text(min(count, 99), format: .number)

                if count > 99 {
                    Text("+")
                }
            }
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 10).fill(.accent)
            )
        }
    }

    private var suggestions: some View {
        List {
            ForEach(viewModel.contactSuggestions) { contact in
                HStack {
                    ProfileImageView(emailAddress: contact.address, size: 30)

                    VStack(alignment: .leading, spacing: 0) {
                        if let name = contact.cachedName {
                            Text(name)
                            Text(contact.address)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(contact.address)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard let address = EmailAddress(contact.address) else { return }
                    viewModel.addReader(address)
                    pendingEmailAddress = ""
                }
            }
        }
        .listStyle(.plain)
        .padding(.horizontal, -20)
    }
}

#Preview {
    ComposeMessageView(action: .newMessage(id: UUID(), authorAddress: "mickey@mouse.com", readerAddress: nil))
}

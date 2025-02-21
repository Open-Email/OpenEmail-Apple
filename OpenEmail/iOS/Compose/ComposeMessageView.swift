import SwiftUI
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel
import Logging
import PhotosUI

enum ComposeResult {
    case cancel
    case sent
}

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

    @State private var filePickerOpen: Bool = false
    @State private var photoPickerOpen: Bool = false
    @State private var photoPickerItems: [PhotosPickerItem] = []

    private var onClose: ((ComposeResult) -> Void)?

    private var showsSuggestions: Bool {
        isReadersFocused && !viewModel.contactSuggestions.isEmpty
    }

    init(action: ComposeAction, onClose: ((ComposeResult) -> Void)? = nil) {
        viewModel = ComposeMessageViewModel(action: action)
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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
                            label: { ReadersLabelView() }
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

                        VStack(alignment: .leading) {
                            AutoResizingTextEditor(text: $viewModel.fullText)

                            if !viewModel.attachedFileItems.isEmpty {
                                ComposeAttachmentsListView(attachedFileItems: $viewModel.attachedFileItems, onDelete: {
                                    viewModel.removeAttachedFileItem(item: $0)
                                })
                                .padding(.top, .Spacing.default)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.updateDraft()
                        dismiss()
                        onClose?(.cancel)
                    }
                    .disabled(viewModel.isSending)
                }

                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button("Photo Library", systemImage: "photo.on.rectangle") {
                            photoPickerOpen = true
                        }

                        Button("Attach File", systemImage: "document") {
                            filePickerOpen = true
                        }
                    } label: {
                        Image(.attachment)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24)
                    }
                    .help("Add files to the message")
                    .disabled(viewModel.isSending)
                }

                ToolbarItem(placement: .primaryAction) {
                    AsyncButton {
                        await sendMessage()
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
            .photosPicker(isPresented: $photoPickerOpen, selection: $photoPickerItems)
            .fileImporter(
                isPresented: $filePickerOpen,
                allowedContentTypes: [.data, .image],
                allowsMultipleSelection: true
            ) {
                do {
                    let urls = try $0.get()
                    let attachments = urls.compactMap { AttachedFileItem(url: $0) }
                    viewModel.attachedFileItems.append(contentsOf: attachments)
                } catch {
                    Log.error("error reading files: \(error)")
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
            .onChange(of: photoPickerItems) {
                Task { await addSelectedPhotoItems() }
            }
        }
        .blur(radius: viewModel.isSending ? 4 : 0)
        .overlay {
            if viewModel.isSending {
                Color(uiColor: .systemBackground).opacity(0.7)

                VStack(spacing: .Spacing.xSmall) {
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
    }

    private var suggestions: some View {
        LazyVStack {
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
    }

    private func sendMessage() async {
        do {
            try await viewModel.send()
            dismiss()
            onClose?(.sent)
        } catch {
            guard !(error is CancellationError) else {
                return
            }

            showsError = true
            self.error = error
            Log.error("Error sending message: \(error)")
        }
    }

    private func addSelectedPhotoItems() async {
        guard !photoPickerItems.isEmpty else { return }

        do {
            for item in photoPickerItems {
                guard let imageData = try? await item.loadTransferable(type: Data.self) else {
                    continue
                }
                try await viewModel.addAttachmentItem(from: imageData)
            }
        } catch {
            Log.error("Could not add attachment: \(error)")
        }

        photoPickerItems = []
    }

}

private struct AutoResizingTextEditor: View {
    @Binding var text: String
    @State private var textHeight: CGFloat = 40 // Minimum height

    var body: some View {
        TextEditor(text: $text)
            .frame(height: textHeight)
            .scrollDisabled(true)
            .font(.body)
            .padding(.horizontal, -4)
            .background(GeometryReader { proxy in
                Color.clear.onAppear {
                    textHeight = calculateHeight()
                }
            })
            .onChange(of: text) {
                textHeight = calculateHeight()
            }
    }

    private func calculateHeight() -> CGFloat {
        let newSize = text.boundingRect(
            with: CGSize(width: UIScreen.main.bounds.width - .Spacing.default * 2, height: .infinity),
            options: .usesLineFragmentOrigin,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body)
            ],
            context: nil
        ).height
        return max(40, newSize + 20)
    }
}

#Preview {
    ComposeMessageView(action: .newMessage(id: UUID(), authorAddress: "mickey@mouse.com", readerAddress: nil))
}

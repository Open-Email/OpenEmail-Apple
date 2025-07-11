import SwiftUI
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel
import Logging
import PhotosUI
import HighlightedTextEditor

enum ComposeResult {
    case cancel
    case sent
}

struct ComposeMessageView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @AppStorage(UserDefaultsKeys.profileName) private var profileName: String?
    @Injected(\.syncService) private var syncService
    @State private var viewModel: ComposeMessageViewModel
    @FocusState private var isTextEditorFocused: Bool
    @FocusState private var isReadersFocused: Bool
    @FocusState private var isBodyFocused: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var hasInvalidReader = false

    @State private var showsError = false
    @State private var error: Error?

    @State private var pendingEmailAddress: String = ""

    @State private var filePickerOpen: Bool = false
    @State private var photoPickerOpen: Bool = false
    @State private var videoPickerOpen: Bool = false
    @State private var mediaFilter: PHPickerFilter? = nil
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var videoPickerItems: [PhotosPickerItem] = []
    @State private var bodyText: String = ""

    private var onClose: ((ComposeResult) -> Void)?

    init(action: ComposeAction, onClose: ((ComposeResult) -> Void)? = nil) {
        viewModel = ComposeMessageViewModel(action: action)
        self.onClose = onClose
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
                }
                
                HStack(spacing: .Spacing.xSmall) {
                    Text("Subject:")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    TextField("", text: $viewModel.subject)
                }
                .padding(.vertical, .Spacing.xSmall)
                
                Divider()
                
                HighlightedTextEditor(text: $bodyText, highlightRules: .markdown)
                
                if !viewModel.attachedFileItems.isEmpty {
                    ComposeAttachmentsListView(attachedFileItems: $viewModel.attachedFileItems, onDelete: {
                        viewModel.removeAttachedFileItem(item: $0)
                    })
                    .padding(.top, .Spacing.default)
                }
                
                if viewModel.attachmentLoading {
                    ProgressView()
                }
            }
            .animation(.default, value: viewModel.isBroadcast)
            .padding(.horizontal, .Spacing.default)
            .onChange(of: bodyText) {
                viewModel.fullText = bodyText
            }
            .onChange(of: viewModel.fullText) {
                self.bodyText = viewModel.fullText
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isBodyFocused.toggle()
            }
            .scrollDismissesKeyboard(.interactively)
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
                        
                        Button("Video Library", systemImage: "movieclapper") {
                            videoPickerOpen = true
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
            .photosPicker(isPresented: $photoPickerOpen, selection: $photoPickerItems, matching: .images)
            .photosPicker(isPresented: $videoPickerOpen, selection: $videoPickerItems, matching: .videos)
            .fileImporter(
                isPresented: $filePickerOpen,
                allowedContentTypes: [UTType.data],
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
            .onChange(of: viewModel.attachedFileItems) {
                viewModel.updateDraft()
            }
            .onChange(of: videoPickerItems) {
                
                guard videoPickerItems.isNotEmpty else { return }
                
                Task {
                    await viewModel
                        .addAttachments(
                            videoPickerItems,
                            type: ComposeMessageViewModel.AttachmentType.video
                        )
                    
                    videoPickerItems.removeAll()
                }
            }
            .onChange(of: photoPickerItems) {
                
                guard photoPickerItems.isNotEmpty else { return }
                
                Task {
                    await viewModel
                        .addAttachments(
                            photoPickerItems,
                            type: ComposeMessageViewModel.AttachmentType.image
                        )
                    
                    photoPickerItems.removeAll()
                }
            }
        }
        .blur(radius: viewModel.isSending ? 4 : 0)
        .overlay {
            if viewModel.isSending {
                Color(uiColor: .systemBackground).opacity(0.7)

                ProgressView()
            }
        }
    }

    private func sendMessage() async {
        await viewModel.send()
        Task.detached(priority: .userInitiated) {
            await syncService.synchronize()
        }
        dismiss()
        onClose?(.sent)
    }
}

private struct AutoResizingTextEditor: View {
    @Binding var text: String
    @State private var textHeight: CGFloat = 40 // Minimum height
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        TextEditor(text: $text)
            .focused($isFocused)
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

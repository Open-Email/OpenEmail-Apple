import SwiftUI
import OpenEmailCore
import OpenEmailPersistence
import OpenEmailModel
import Logging
import Inspect
import Flow
import UniformTypeIdentifiers
import HighlightedTextEditor

@MainActor
struct ComposeMessageView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @AppStorage(UserDefaultsKeys.profileName) private var profileName: String?
    
    @Bindable var viewModel: ComposeMessageViewModel
    @FocusState private var isReadersFocused: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var hasInvalidReader = false
    @State private var filePickerOpen: Bool = false
    
    @State private var showsError = false
    @State private var error: Error?
    
    @State private var hoveredFileItem: AttachedFileItem?
    @State private var isDropping: Bool = false
    @State private var addingContactProgress: Bool = false
    
    @State private var shownProfileAddress: EmailAddress?
    @State private var bodyText: String = ""
    init(viewModel: ComposeMessageViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            readersRow
            Divider()
            subjectRow
            Divider()
           
            HighlightedTextEditor(text: $bodyText, highlightRules: .markdown)
                .padding(.vertical, .Spacing.xSmall)
                .scrollDisabled(true)
            
            if !viewModel.attachedFileItems.isEmpty {
                HFlow(itemSpacing: .Spacing.small, rowSpacing: .Spacing.small) {
                    ForEach(viewModel.attachedFileItems) { item in
                        fileItemView(item: item)
                    }
                    Spacer()
                }
                
                .padding(.vertical, .Spacing.default)
            }
            
        }
        .onAppear {
            Task {
                self.bodyText = await viewModel.getInitialBodyOfDraft()
            }
        }
        .onChange(of: bodyText) {
            viewModel.fullText = bodyText
        }
        .padding(.horizontal, .Spacing.default)
        .background(.themeViewBackground)
        .frame(minWidth: 510, minHeight: 420, maxHeight: .infinity)
        .fileImporter(isPresented: $filePickerOpen, allowedContentTypes: [.data], allowsMultipleSelection: true) {
            do {
                let urls = try $0.get()
                viewModel.appendAttachedFiles(urls: urls)
            }
            catch {
                Log.error("error reading files: \(error)")
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: .CornerRadii.default) // use invisible rectangle as drop target
                .fill(.clear)
                .stroke(isDropping ? .accent : .clear, lineWidth: 2)
                .onDrop(of: [.fileURL], isTargeted: $isDropping) { items -> Bool in
                    Task {
                        await dropItems(items)
                    }
                    return true
                    
                }
        }
        .alert(
            "Could not send message",
            isPresented: $showsError,
            actions: {},
            message: {
                if let error {
                    Text("Underlying error: \(String(describing: error))")
                }
            }
        )
        .overlay {
            if viewModel.isSending {
                Color(nsColor: .windowBackgroundColor).opacity(0.7)
                
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
        }.animation(.default, value: viewModel.isBroadcast)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        HStack {
                            Text("Broadcast").font(.subheadline).onTapGesture {
                                viewModel.isBroadcast.toggle()
                            }
                            Toggle("Broadcast", isOn: $viewModel.isBroadcast)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }.disabled(!viewModel.canBroadcast).padding(
                            .horizontal,
                            .Spacing.default
                        )
                        Button {
                            filePickerOpen = true
                        } label: {
                            Image( systemName: "paperclip")
                            
                        }
                        .help("Add files to the message")
                        Divider()
                        AsyncButton {
                            //TODO save to pending local store simmilar to Android
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
                            Image(systemName: "paperplane")
                        }
                        .disabled(hasInvalidReader || !viewModel.isSendButtonEnabled || addingContactProgress)
                        .help(viewModel.hasAllDataForSending ? "" : "Subject and message fields are required")
                    }
                }
            }
    }
    
    @ViewBuilder
    private var readersRow: some View {
        if !viewModel.isBroadcast {
            HStack {
                if viewModel.action.isReplyAction {
                    HStack(spacing: .Spacing.xxxSmall) {
                        Image(systemName: "arrowshape.turn.up.left")
                        Text("Reply to:").font(.body)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    ReadersLabelView()
                }
                
                ReadersView(
                    isEditable: true,
                    readers: $viewModel.readers,
                    tickedReaders: .constant([]),
                    hasInvalidReader: $hasInvalidReader,
                    addingContactProgress: $addingContactProgress,
                    showProfileType: .popover
                )
                .focused($isReadersFocused)
            }
        }
    }
    
    @ViewBuilder
    private var subjectRow: some View {
        HStack {
            Text("Subject:")
                .foregroundStyle(.secondary).font(.body)
            TextField("", text: $viewModel.subject)
                .font(.body)
                .textFieldStyle(.plain)
                .padding(.vertical, .Spacing.xSmall)
        }
    }
    
    @ViewBuilder
    private func fileItemView(item: AttachedFileItem) -> some View {
        HStack(spacing: .Spacing.small) {
            if item.exists {
                item.icon.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48)
                    .padding(.horizontal, -4) // adjust for empty space around file icons
            } else {
                WarningIcon()
            }
            
            VStack(alignment: .leading, spacing: .Spacing.xxxSmall) {
                Text(item.url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(item.url.lastPathComponent)
                
                if let size = item.size {
                    Text(Formatters.fileSizeFormatter.string(fromByteCount: size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(item.exists ? Color.primary : Color.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            let canDelete = hoveredFileItem?.url == item.url
            Button {
                viewModel.removeAttachedFileItem(item: item)
            } label: {
                Image(.trash)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 24, height: 24)
            .background {
                Circle().stroke(.tertiary)
            }
            .buttonStyle(.plain)
            .opacity(canDelete ? 1 : 0)
        }
        .padding(.Spacing.xSmall)
        .padding(.trailing, .Spacing.xxSmall)
        .frame(width: 224, height: 64)
        .background {
            RoundedRectangle(cornerRadius: .CornerRadii.default)
                .stroke(.actionButtonOutline)
        }
        .contentShape(RoundedRectangle(cornerRadius: .CornerRadii.default))
        .onHover { hovering in
            if hovering {
                hoveredFileItem = item
            } else {
                if hoveredFileItem?.url == item.url {
                    hoveredFileItem = nil
                }
            }
        }
    }
    
    private func dropItems(_ items: [NSItemProvider]) async -> Bool {
        do {
            var droppedUrls: [URL] = []
            try await withThrowingTaskGroup(of: Void.self) { group in
                for item in items {
                    group.addTask {
                        // Load the raw item
                        let loaded = try await item.loadItem(
                            forTypeIdentifier: UTType.fileURL.identifier,
                            options: nil
                        )
                        
                        // Try casting to URL directly
                        if let url = loaded as? URL {
                            droppedUrls.append(url)
                        }
                        
                        // Fallback: maybe Data‑encoded URL string
                        if let data = loaded as? Data,
                           let str = String(data: data, encoding: .utf8),
                           let url = URL(string: str) {
                            droppedUrls.append(url)
                        }
                        
                    }
                }
                
                try await group.waitForAll()
            }
            
            viewModel
                .appendAttachedFiles(urls: droppedUrls)
            
            return true
        } catch {
            Log.error(error)
            return false
        }
    }
}

#Preview {
    let viewModel = ComposeMessageViewModel(action: .newMessage(id: UUID(), authorAddress: "mickey@mouse.com", readerAddress: nil))
    viewModel.appendAttachedFiles(
        urls: [
            URL(fileURLWithPath: "/path/to/file.jpg"),
            URL(fileURLWithPath: "/path/to/file2.jpg"),
            URL(fileURLWithPath: "/path/to/file3.jpg"),
            URL(fileURLWithPath: "/path/to/file4.jpg"),
            URL(fileURLWithPath: "/path/to/file5.jpg"),
        ]
    )
    return ComposeMessageView(viewModel: viewModel)
}

#Preview("sending") {
    ComposeMessageView(viewModel: ComposeMessageViewModel(action: .newMessage(id: UUID(),  authorAddress: "mickey@mouse.com", readerAddress: nil)))
}

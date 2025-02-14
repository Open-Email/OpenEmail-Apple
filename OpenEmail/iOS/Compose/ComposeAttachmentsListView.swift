import SwiftUI
import Logging
import PhotosUI

struct ComposeAttachmentsListView: View {
    @Binding private var attachedFileItems: [AttachedFileItem]
    @State private var filePickerOpen: Bool = false
    @State private var photoPickerOpen: Bool = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var previewFileUrl: URL?

    @State private var viewModel = ComposeAttachmentsListViewModel()

    @Environment(\.dismiss) var dismiss

    init(attachedFileItems: Binding<[AttachedFileItem]>, messageId: String) {
        _attachedFileItems = attachedFileItems
        viewModel.attachedFileItems = attachedFileItems.wrappedValue
        viewModel.messageId = messageId
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach($viewModel.attachedFileItems) { item in
                    attachmentItemView(item: item.wrappedValue)
                }
            }
            .quickLookPreview($previewFileUrl)
            .overlay {
                if viewModel.attachedFileItems.count == 0 {
                    Text("No attachments")
                        .bold()
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Add files", systemImage: "doc") {
                        filePickerOpen = true
                    }
                    Button("Add photos", systemImage: "photo.on.rectangle") {
                        photoPickerOpen = true
                    }
                }

                ToolbarItem {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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
            .photosPicker(isPresented: $photoPickerOpen, selection: $photoPickerItems)
            .onChange(of: photoPickerItems) {
                Task { await addSelectedPhotoItems() }
            }
            .onChange(of: viewModel.attachedFileItems) {
                attachedFileItems = viewModel.attachedFileItems
            }
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

    @ViewBuilder
    private func attachmentItemView(item: AttachedFileItem) -> some View {
        HStack {
            item.icon.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 40)

            VStack(alignment: .leading) {
                Text(item.url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let fileSize = item.size {
                    let formattedFileSize = Formatters.fileSizeFormatter.string(fromByteCount: Int64(fileSize))
                    Text(formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onTapGesture {
            previewFileUrl = item.url
        }
        .swipeActions(edge: .leading) {
            Button("Preview", systemImage: "eye") {
                previewFileUrl = item.url
            }
            .tint(.indigo)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                viewModel.removeAttachmentItem(item)
            }
        }
    }
}

#Preview {
    let items = [
        AttachedFileItem(url: URL(fileURLWithPath: "/abc/file.pdf"), icon: .iconForMimeType("application/pdf"), size: 12345),
        AttachedFileItem(url: URL(fileURLWithPath: "/abc/image.jpg"), icon: .iconForMimeType("image/jpeg"), size: 1234)
    ]

    ComposeAttachmentsListView(attachedFileItems: .constant(items), messageId: "123")
}

#Preview("Empty") {
    ComposeAttachmentsListView(attachedFileItems: .constant([]), messageId: "123")
}


import SwiftUI
import OpenEmailModel
import OpenEmailCore
import QuickLook
import CoreTransferable
import Flow

struct AttachmentsListView: View {
    var viewModel: AttachmentsListViewModel

    @State private var selection: AttachmentItem.ID?
    @State private var previewFileUrl: URL?
    @State private var sharedFileUrl: URL?
    @State private var savedFileUrl: URL?
    @State private var showDownloadBigFileWarning = false
    @State private var selectedAttachmentItem: AttachmentItem?

    @Injected(\.attachmentsManager) private var attachmentsManager

    @Injected(\.networkConnectionMonitor) private var networkConnectionMonitor

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: .Spacing.small) {
            Text("Attachments (\(viewModel.items.count))")
                .font(.headline)

            HFlow(alignment: .top, itemSpacing: .Spacing.small, rowSpacing: .Spacing.small) {
                ForEach(viewModel.items) { item in
                    AttachmentItemView(
                        item: item,
                        isDraft: viewModel.isDraft,
                        isMessageDeleted: viewModel.isMessageDeleted,
                        onDownload: { attachment in
                            if attachment.isBig && networkConnectionMonitor.isOnCellular {
                                selectedAttachmentItem = item
                                showDownloadBigFileWarning = true
                            } else {
                                attachmentsManager.download(attachment: attachment)
                            }
                        }
                    )
                    .contextMenu {
                        messageFileContextMenuItems(item: item)
                    }
                    .onTapGesture {
                        if
                            let attachment = item.attachment,
                            let url = attachmentsManager.fileUrl(for: attachment)
                        {
                            previewFileUrl = url
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .quickLookPreview($previewFileUrl)
        .background(
            ActivityView(
                isPresented: .init(get: { sharedFileUrl != nil }, set: { if $0 == false { sharedFileUrl = nil } }),
                data: [sharedFileUrl].compactMap { $0 }
            )
        )
        .sheet(isPresented: .init(get: { savedFileUrl != nil }, set: { if $0 == false { savedFileUrl = nil } })) {
            if let savedFileUrl {
                DocumentPicker(url: savedFileUrl) { _ in
                    self.savedFileUrl = nil
                }
            }
        }
        .onChange(of: attachmentsManager.downloadInfos) {
            Task {
                await viewModel.updateItems()
            }
        }
        .onAppear {
            networkConnectionMonitor.start()
        }
        .onDisappear {
            networkConnectionMonitor.stop()
        }
        .confirmationDialog(
            "Download big file?",
            isPresented: $showDownloadBigFileWarning,
            titleVisibility: .visible,
            actions: {
                Button("Download") {
                    guard let attachment = selectedAttachmentItem?.attachment else {
                        return
                    }
                    attachmentsManager.download(attachment: attachment)
                    showDownloadBigFileWarning = false
                }

                Button("Cancel", role: .cancel) {
                    showDownloadBigFileWarning = false
                }
            }) {
                if let selectedAttachmentItem, let fileSize = selectedAttachmentItem.formattedFileSize {
                    Text("This file is \(fileSize) and you are on a cellular connection.")
                }
            }
    }

    @ViewBuilder @MainActor
    private func messageFileContextMenuItems(item: AttachmentItem) -> some View {
        if
            let attachment = item.attachment,
            let fileUrl = attachmentsManager.fileUrl(for: attachment)
        {
            Button {
                previewFileUrl = fileUrl
            } label: {
                Text("Quick Look")
                Image(systemName: "eye")
            }

            Button {
                savedFileUrl = fileUrl
            } label: {
                Text("Save to Files")
                Image(systemName: "folder")
            }

            Button {
                sharedFileUrl = fileUrl
            } label: {
                Text("Share")
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}

private extension Attachment {
    var isBig: Bool {
        size >= 100_000_000 // 100 MegaBytes
    }
}

#if DEBUG
#Preview {
    let messageStore = MessageStoreMock()
    messageStore.stubMessages = [
        .makeRandom(id: "1"),
        .makeRandom(id: "2"),
        .makeRandom(id: "3"),
        .makeRandom(id: "4"),
    ]
    InjectedValues[\.messagesStore] = messageStore

    let attachment1 = Attachment(id: "2_picture.jpg", parentMessageId: "2", fileMessageIds: ["22"], filename: "picture.jpg", size: 123456, mimeType: "image/jpeg")
    let attachment2 = Attachment(id: "3_documents.zip", parentMessageId: "3", fileMessageIds: ["33"], filename: "documents.zip", size: 654321, mimeType: "application/zip")
    let attachment3 = Attachment(id: "4_doc.pdf", parentMessageId: "4", fileMessageIds: ["44"], filename: "doc.pdf", size: 12345, mimeType: "application/pdf")

    let viewModel = AttachmentsListViewModel(localUserAddress: "pera@toons.com", message: messageStore.stubMessages[0], attachments: [attachment1, attachment2, attachment3])
    return AttachmentsListView(viewModel: viewModel)
        .padding()
}
#endif

import SwiftUI
import OpenEmailModel
import OpenEmailCore
import QuickLook
import CoreTransferable
import Flow

struct AttachmentsListView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Injected(\.attachmentsManager) private var attachmentsManager
    @Injected(\.networkConnectionMonitor) private var networkConnectionMonitor

    @State private var selection: AttachmentItem.ID?
    @State private var previewFileUrl: URL?
    @State private var sharedFileUrl: URL?
    @State private var savedFileUrl: URL?
    @State private var showDownloadBigFileWarning = false
    @State private var selectedAttachmentItem: AttachmentItem?
    
    private var attachmentItems: [AttachmentItem] = []
    init(_ attachments: [Attachment]) {
        self.attachmentItems = attachments.map {
            AttachmentItem(
                localUserAddress: registeredEmailAddress ?? "",
                attachment: $0,
                isAvailable: attachmentsManager.fileUrl(for: $0) != nil,
                isDraft: false,
                formattedFileSize: Formatters.fileSizeFormatter
                    .string(fromByteCount: Int64($0.size)),
                icon: $0.fileIcon,
                draftFileUrl: nil
            )
        }
    }
    
    var body: some View {

        VStack(alignment: .leading, spacing: .Spacing.small) {
            Text("Attachments (\(attachmentItems.count))")
                .font(.headline)

            HFlow(alignment: .top, itemSpacing: .Spacing.small, rowSpacing: .Spacing.small) {
                ForEach(attachmentItems) { item in
                    AttachmentItemView(
                        item: item,
                        isDraft: item.isDraft,
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
    let attachment1 = Attachment(id: "1_picture.jpg", parentMessageId: "1", fileMessageIds: ["2"], filename: "picture.jpg", size: 123456, mimeType: "image/jpeg")
    let attachment2 = Attachment(id: "1_documents.zip.jpg", parentMessageId: "2", fileMessageIds: ["3"], filename: "documents.zip", size: 654321, mimeType: "application/zip")
    
    AttachmentsListView([attachment1, attachment2])
        .frame(width: 800)
        .padding()
        .background(.themeViewBackground)
}
#endif

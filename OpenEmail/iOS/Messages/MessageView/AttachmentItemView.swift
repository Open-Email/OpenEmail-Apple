import SwiftUI
import OpenEmailModel

struct AttachmentItemView: View {
    let item: AttachmentItem
    let isDraft: Bool

    let onDownload: (Attachment) -> Void

    @Injected(\.attachmentsManager) private var attachmentsManager

    var body: some View {
        HStack(spacing: .Spacing.small) {
            let isMissingDraftFile = isDraft && !item.isAvailable
            let attachmentNotDownloaded = !isDraft && !item.isAvailable

            if isMissingDraftFile {
                WarningIcon()
            } else {
                item.icon.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: .Spacing.xxLarge, height: .Spacing.xxLarge)
            }

            VStack(alignment: .leading, spacing: .Spacing.xxxSmall) {
                Text(item.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(item.displayName)

                if let formattedFileSize = item.formattedFileSize {
                    Text(formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(isMissingDraftFile ? Color.red : Color.primary)

            Spacer()
            if attachmentNotDownloaded, let attachment = item.attachment {
                if let downloadInfo = attachmentsManager.downloadInfos[attachment.id] {
                    if let error = downloadInfo.progress.error {
                        HStack {
                            ErrorIcon().help(error.localizedDescription)
                            downloadButton(attachment: attachment)
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                } else {
                    downloadButton(attachment: attachment)
                }
            }
        }
        .padding(.Spacing.xSmall)
        .background {
            RoundedRectangle(cornerRadius: .CornerRadii.default)
                .stroke(Color.themeLineGray)
        }
        .frame(maxWidth: 600)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func downloadButton(attachment: Attachment) -> some View {
        Button {
            onDownload(attachment)
        } label: {
            Image(.attachmentDownload)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color.themePrimary)
                .frame(width: .Spacing.large)
                .padding(.Spacing.xSmall)
                .background {
                    Circle()
                        .stroke(Color.themeLineGray)
                }
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}

#Preview("to download") {
    let item = AttachmentItem(
        localUserAddress: "mickey@mouse.com",
        attachment: .init(id: "123", parentMessageId: "1", fileMessageIds: ["2"], filename: "hello.jpg", size: 123, mimeType: ""),
        isAvailable: false,
        isDraft: false,
        formattedFileSize: "123 kB",
        icon: .defaultFileIcon,
        draftFileUrl: nil
    )

    VStack(spacing: 8) {
        AttachmentItemView(item: item, isDraft: false, onDownload: { _ in })
        AttachmentItemView(item: item, isDraft: false, onDownload: { _ in })
    }
    .padding()
}

#Preview("downloaded") {
    let item = AttachmentItem(
        localUserAddress: "mickey@mouse.com",
        attachment: .init(id: "123", parentMessageId: "1", fileMessageIds: ["2"], filename: "hello.jpg", size: 123, mimeType: ""),
        isAvailable: true,
        isDraft: false,
        formattedFileSize: "123 kB",
        icon: .defaultFileIcon,
        draftFileUrl: nil
    )

    AttachmentItemView(item: item, isDraft: false, onDownload: { _ in })
        .padding()
}

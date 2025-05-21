import SwiftUI
import OpenEmailModel

struct AttachmentItemView: View {
    let item: AttachmentItem
    let isDraft: Bool

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
                    .frame(width: 48)
                    .padding(.horizontal, -4) // adjust for empty space around file icons
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
            .frame(maxWidth: .infinity, alignment: .leading)

            if attachmentNotDownloaded, let attachment = item.attachment {
                Spacer()

                if let downloadInfo = attachmentsManager.downloadInfos[attachment.id] {
                    if let error = downloadInfo.progress.error {
                        HStack(spacing: .Spacing.xxSmall) {
                            ErrorIcon().help(error.localizedDescription)
                            downloadButton(attachment: attachment)
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    }
                } else {
                    downloadButton(attachment: attachment)
                }
            }
        }
        .padding(.Spacing.xSmall)
        .padding(.trailing, .Spacing.xxSmall)
        .frame(width: 224, height: 64)
        .background {
            RoundedRectangle(cornerRadius: .CornerRadii.default)
                .fill(.clear)
                .stroke(.actionButtonOutline)
        }
        .contentShape(RoundedRectangle(cornerRadius: .CornerRadii.default))
    }

    @ViewBuilder
    private func downloadButton(attachment: Attachment) -> some View {
        Button {
            _ = attachmentsManager.download(attachment: attachment)
        } label: {
            Image(systemName: "icloud.and.arrow.down")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        .foregroundStyle(.accent)
        .buttonStyle(.plain)
        .frame(width: 16)
    }
}

#Preview("to download") {
    let item = AttachmentItem(
        localUserAddress: "mickey@mouse.com",
        attachment: .init(id: "123", parentMessageId: "1", fileMessageIds: ["2"], filename: "hello.jpg", size: 123, mimeType: ""),
        isAvailable: false,
        isDraft: false,
        formattedFileSize: "123 kB",
        icon: NSWorkspace.shared.defaultFileIcon,
        draftFileUrl: nil
    )

    AttachmentItemView(item: item, isDraft: false)
        .padding()
}

#Preview("downloaded") {
    let item = AttachmentItem(
        localUserAddress: "mickey@mouse.com",
        attachment: .init(id: "123", parentMessageId: "1", fileMessageIds: ["2"], filename: "hello.jpg", size: 123, mimeType: ""),
        isAvailable: true,
        isDraft: true,
        formattedFileSize: "123 kB",
        icon: NSWorkspace.shared.defaultFileIcon,
        draftFileUrl: nil
    )

    AttachmentItemView(item: item, isDraft: false)
        .padding()
}

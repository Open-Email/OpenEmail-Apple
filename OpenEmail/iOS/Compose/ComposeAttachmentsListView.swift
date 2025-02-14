import SwiftUI

struct ComposeAttachmentsListView: View {
    @Binding var attachedFileItems: [AttachedFileItem]
    var onDelete: (AttachedFileItem) -> Void

    @State private var previewFileUrl: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
            ForEach($attachedFileItems) { item in
                attachmentItemView(item: item.wrappedValue)
            }
        }
        .frame(maxWidth: .infinity)
        .quickLookPreview($previewFileUrl)
    }

    @ViewBuilder
    private func attachmentItemView(item: AttachedFileItem) -> some View {
        HStack(spacing: .Spacing.small) {
            item.icon.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: .Spacing.xxLarge)

            VStack(alignment: .leading) {
                Text(item.url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.subheadline)

                if let fileSize = item.size {
                    let formattedFileSize = Formatters.fileSizeFormatter.string(fromByteCount: Int64(fileSize))
                    Text(formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                onDelete(item)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.themeIconBackground)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle().stroke(Color.themeLineGray)
                        }

                    Image(.delete)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.themePrimary)
                }
                .frame(width: 40, height: 40)
                .contentShape(Circle())
            }
        }
        .padding(.Spacing.xSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: .CornerRadii.small).stroke(Color.themeLineGray)
        }
        .contentShape(RoundedRectangle(cornerRadius: .CornerRadii.small))
        .onTapGesture {
            previewFileUrl = item.url
        }
        .animation(.default, value: attachedFileItems)
    }
}

#Preview {
    let items = [
        AttachedFileItem(url: URL(fileURLWithPath: "/abc/file.pdf"), icon: .iconForMimeType("application/pdf"), size: 12345),
        AttachedFileItem(url: URL(fileURLWithPath: "/abc/image.jpg"), icon: .iconForMimeType("image/jpeg"), size: 1234)
    ]

    ComposeAttachmentsListView(attachedFileItems: .constant(items), onDelete: { _ in })
        .padding()
}

#Preview("Empty") {
    ComposeAttachmentsListView(attachedFileItems: .constant([]), onDelete: { _ in })
}


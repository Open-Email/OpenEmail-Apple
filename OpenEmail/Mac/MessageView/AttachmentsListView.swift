import SwiftUI
import OpenEmailModel
import OpenEmailCore
import AppKit
import Flow

struct AttachmentsListView: View {
    let viewModel: AttachmentsListViewModel

    @State private var selection = Set<AttachmentItem.ID>()

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.small) {
            Text("Attachments (\(viewModel.items.count))")
                .font(.headline)

            HFlow(alignment: .top, itemSpacing: .Spacing.small, rowSpacing: .Spacing.small) {
                ForEach(viewModel.items) { item in
                    AttachmentItemView(
                        item: item,
                        isDraft: item.isDraft
                    )
                    .onTapGesture(count: 2) {
                        if item.isAvailable {
                            viewModel.openFile(with: item.id)
                        }
                    }
                    .contextMenu {
                        if item.isAvailable {
                            if item.isDraft {
                                draftFileContextMenuItems(items: [item.id])
                            } else {
                                messageFileContextMenuItems(items: [item.id])
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder @MainActor
    private func messageFileContextMenuItems(items: Set<AttachmentItem.ID>) -> some View {
        if items.isEmpty { // empty area
            Button("Save All…") {
                viewModel.saveFiles(with: Set(viewModel.items.map { $0.id }))
            }
        } else if items.count == 1 { // single item
            if  let itemID = items.first {
                Button("Open") {
                    viewModel.openFile(with: itemID)
                }

                Button("Save…") {
                    viewModel.saveFile(with: itemID)
                }
            }
        } else { // multiple items
            Button("Save Selected…") {
                viewModel.saveFiles(with: items)
            }
        }
    }

    @ViewBuilder @MainActor
    private func draftFileContextMenuItems(items: Set<AttachmentItem.ID>) -> some View {
        Button("Reveal in Finder") {
            viewModel.revealDraftAttachmentInFinder(itemIDs: items)
        }
    }
}

#if DEBUG
#Preview {
   

    let attachment1 = Attachment(id: "1_picture.jpg", parentMessageId: "1", fileMessageIds: ["2"], filename: "picture.jpg", size: 123456, mimeType: "image/jpeg")
    let attachment2 = Attachment(id: "1_documents.zip.jpg", parentMessageId: "2", fileMessageIds: ["3"], filename: "documents.zip", size: 654321, mimeType: "application/zip")

    let viewModel = AttachmentsListViewModel()
    AttachmentsListView(viewModel: viewModel)
        .frame(width: 800)
        .padding()
        .background(.themeViewBackground)
}
#endif

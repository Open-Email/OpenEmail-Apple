import Foundation
import Observation
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence
import UIKit
import UniformTypeIdentifiers
import Logging
import Utils

struct AttachmentItem: Identifiable {
    var id: String { attachment?.id ?? draftFileUrl?.path() ?? UUID().uuidString }

    let localUserAddress: String
    let attachment: Attachment?
    let isAvailable: Bool
    let formattedFileSize: String?
    let icon: OEImage
    let draftFileUrl: URL?

    var locations: [URL] {
        guard let attachment else { return [] }

        let messagesDirectoryUrl = FileManager.default.documentsDirectoryUrl()
            .appendingPathComponent(MESSAGES_DIRECTORY)
            .appendingPathComponent(localUserAddress)
        return attachment.fileMessageIds.map {
            messagesDirectoryUrl
                .appendingPathComponent(attachment.parentMessageId)
                .appendingPathComponent("\($0).\(PAYLOAD_FILENAME)")
        }
    }

    var displayName: String {
        attachment?.filename ?? draftFileUrl?.lastPathComponent ?? ""
    }
}

@Observable
class AttachmentsListViewModel {
    var items: [AttachmentItem] = []
    var isDraft: Bool
    var isMessageDeleted: Bool {
        message.isDeleted
    }

    private let localUserAddress: String
    private let message: Message

    private let attachments: [Attachment]

    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore

    @ObservationIgnored
    @Injected(\.attachmentsManager) private var attachmentsManager

    init(localUserAddress: String, message: Message, attachments: [Attachment]) {
        self.message = message
        self.localUserAddress = localUserAddress
        self.isDraft = false
        self.attachments = attachments

        Task {
            await updateItems()
        }
    }

    init(localUserAddress: String, message: Message, draftAttachmentUrls: [URL]) {
        self.message = message
        self.localUserAddress = localUserAddress
        self.isDraft = true
        self.attachments = []

        items = draftAttachmentUrls.map {
            let path = $0.path(percentEncoded: false)
            return AttachmentItem(
                localUserAddress: localUserAddress,
                attachment: nil,
                isAvailable: !isMessageDeleted && $0.fileExists,
                formattedFileSize: $0.formattedFileSie,
                icon: UIImage.iconForPath(path),
                draftFileUrl: $0
            )
        }
    }

    @MainActor
    func updateItems() async {
        var items: [AttachmentItem] = []
        for attachment in attachments {
            let isAvailable = attachmentsManager.fileUrl(for: attachment) != nil

            let fileSize = Formatters.fileSizeFormatter.string(fromByteCount: Int64(attachment.size))
            let item = AttachmentItem(
                localUserAddress: localUserAddress,
                attachment: attachment,
                isAvailable: !isMessageDeleted && isAvailable,
                formattedFileSize: fileSize,
                icon: attachment.fileIcon,
                draftFileUrl: nil
            )
            items.append(item)
        }

        self.items = items.sorted { item1, item2 in
            item1.displayName.localizedStandardCompare(item2.displayName) == .orderedAscending
        }
    }

    func attachment(withItemId itemID: AttachmentItem.ID) -> Attachment? {
        attachmentItem(withId: itemID)?.attachment
    }

    func attachmentItem(withId itemID: AttachmentItem.ID) -> AttachmentItem? {
        items.first(where: { $0.id == itemID })
    }
}

private extension Attachment {
    var fileIcon: OEImage {
        UIImage.iconForMimeType(mimeType)
    }
}

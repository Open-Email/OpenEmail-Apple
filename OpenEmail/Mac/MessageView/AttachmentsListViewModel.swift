import Foundation
import Observation
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence
import AppKit
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
        attachment?.filename.removingPercentEncoding ?? draftFileUrl?.lastPathComponent ?? ""
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
                icon: NSWorkspace.shared.icon(forFile: path),
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

    func openFile(with id: String) {
        guard
            let item = items.first(where: { $0.id == id }),
            let attachment = item.attachment,
            let fileURL = attachmentsManager.fileUrl(for: attachment)
        else {
            Log.error("Could not open attachment.")
            return
        }

        NSWorkspace.shared.open(fileURL)
    }

    @MainActor 
    func saveFile(with id: String) {
        guard
            let item = items.first(where: { $0.id == id }),
            item.isAvailable
        else {
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = "Save As"
        panel.message = "Select a location to save the file"
        panel.nameFieldStringValue = item.displayName

        let response = panel.runModal()
        if response == .OK {
            guard let selectedURL = panel.url else {
                Log.error("Failed to save file")
                return
            }

            do {
                try concatenateFiles(at: item.locations, to: selectedURL)
            } catch {
                Log.error("Failed to copy file:", context: error)
            }
        }
    }

    @MainActor 
    func saveFiles(with ids: Set<String>) {
        let panel = NSOpenPanel()
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a location to save the files"
        panel.prompt = "Save All"

        let response = panel.runModal()
        if response == .OK {
            guard let selectedURL = panel.url else { return }
            do {
                var overwriteAll = false
                for id in ids {
                    guard
                        let item = items.first(where: { $0.id == id }),
                        item.isAvailable
                    else {
                        Log.error("Failed to save file")
                        return
                    }

                    let destinationURL = selectedURL.appending(path: item.displayName)

                    if !overwriteAll && FileManager.default.fileExists(atPath: destinationURL.path) {
                        let alertResponse = showFileExistsAlert(filename: item.displayName)
                        if alertResponse == .alertFirstButtonReturn {
                            // fall through
                        } else if alertResponse == .alertSecondButtonReturn {
                            overwriteAll = true
                            // fall through
                        } else if alertResponse == .alertThirdButtonReturn {
                            continue
                        } else if alertResponse == NSApplication.ModalResponse(rawValue: 1003) {
                            return
                        }
                    }
                    try concatenateFiles(at: item.locations, to: destinationURL)
                }
            } catch {
                Log.error("Failed to save file:", context: error)
            }
        }
    }

    private func showFileExistsAlert(filename: String) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "File already exists"
        alert.informativeText = "A file named \(filename) already exists at this location. What do you want to do?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Overwrite All") // TODO: replace this with a checkbox as Finder does when copying files
        alert.addButton(withTitle: "Skip this File")
        alert.addButton(withTitle: "Abort")

        return alert.runModal()
    }

    func revealDraftAttachmentInFinder(itemIDs: Set<AttachmentItem.ID>) {
        let urls = items
            .filter { itemIDs.contains($0.id) }
            .compactMap { $0.draftFileUrl }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}

private extension Attachment {
    var fileIcon: OEImage {
        guard let type = UTType(mimeType: mimeType) else {
            return NSWorkspace.shared.defaultFileIcon
        }

        return NSWorkspace.shared.icon(for: type)
    }
}

import Foundation
import Observation
import OpenEmailCore
import OpenEmailModel
import OpenEmailPersistence
import AppKit
import UniformTypeIdentifiers
import Logging
import SwiftUICore
import Utils
import Combine

struct AttachmentItem: Identifiable {
    var id: String { attachment?.id ?? draftFileUrl?.path() ?? UUID().uuidString }

    let localUserAddress: String
    let attachment: Attachment?
    let isAvailable: Bool
    let isDraft: Bool
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
    private var subscriptions = Set<AnyCancellable>()
    private var message: Message?

    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore
    
    @ObservationIgnored
    @Injected(\.attachmentsManager) var attachmentsManager: AttachmentsManager

    func setMessage(message: Message?) {
        self.message = message
        refresh()
    }
    
    func refresh() {
        if let currentUser = LocalUser.current,
        let message = message {
            self.items = message.isDraft ? message.draftAttachmentUrls.map {
                let path = $0.path(percentEncoded: false)
                return AttachmentItem(
                    localUserAddress: currentUser.address.address,
                    attachment: nil,
                    isAvailable: $0.fileExists,
                    isDraft: message.isDraft,
                    formattedFileSize: $0.formattedFileSie,
                    icon: NSWorkspace.shared.icon(forFile: path),
                    draftFileUrl: $0
                )
            } : message.attachments.map {
                return AttachmentItem(
                    localUserAddress: currentUser.address.address,
                    attachment: $0,
                    isAvailable: attachmentsManager.fileUrl(for: $0) != nil,
                    isDraft: message.isDraft,
                    formattedFileSize: Formatters.fileSizeFormatter
                        .string(fromByteCount: Int64($0.size)),
                    icon: $0.fileIcon,
                    draftFileUrl: nil
                )
            }
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

            if let attachment = item.attachment,
               let fileURL = attachmentsManager.fileUrl(for: attachment){
                do {
                    try copyFile(src: fileURL, dst: selectedURL)
                } catch {
                    Log.error("Failed to copy file:", context: error)
                }
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

extension Attachment {
    var fileIcon: OEImage {
        guard let type = UTType(mimeType: mimeType) else {
            return NSWorkspace.shared.defaultFileIcon
        }

        return NSWorkspace.shared.icon(for: type)
    }
}

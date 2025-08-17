import SwiftUI
import OpenEmailModel
import OpenEmailCore
import AppKit
import Flow
import Logging
import Utils

struct AttachmentsListView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) private var registeredEmailAddress: String?
    @Injected(\.attachmentsManager) private var attachmentsManager
    var attachmentItems: [AttachmentItem] = []
    
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
    @State private var selection = Set<AttachmentItem.ID>()

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.small) {
            Text("Attachments (\(attachmentItems.count))")
                .font(.headline)

            HFlow(alignment: .top, itemSpacing: .Spacing.small, rowSpacing: .Spacing.small) {
                ForEach(attachmentItems) { item in
                    AttachmentItemView(
                        item: item,
                        isDraft: item.isDraft
                    )
                    .onTapGesture(count: 2) {
                        if item.isAvailable {
                            openFile(with: item.id)
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
                saveFiles(with: Set(attachmentItems.map { $0.id }))
            }
        } else if items.count == 1 { // single item
            if  let itemID = items.first {
                Button("Open") {
                    openFile(with: itemID)
                }

                Button("Save…") {
                    saveFile(with: itemID)
                }
            }
        } else { // multiple items
            Button("Save Selected…") {
                saveFiles(with: items)
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
                        let item = attachmentItems.first(where: { $0.id == id }),
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
    
    @ViewBuilder @MainActor
    private func draftFileContextMenuItems(items: Set<AttachmentItem.ID>) -> some View {
        Button("Reveal in Finder") {
            revealDraftAttachmentInFinder(itemIDs: items)
        }
    }
    
    func revealDraftAttachmentInFinder(itemIDs: Set<AttachmentItem.ID>) {
        let urls = attachmentItems
            .filter { itemIDs.contains($0.id) }
            .compactMap { $0.draftFileUrl }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
    
    func openFile(with id: String) {
        guard
            let item = attachmentItems.first(where: { $0.id == id }),
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
            let item = attachmentItems.first(where: { $0.id == id }),
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

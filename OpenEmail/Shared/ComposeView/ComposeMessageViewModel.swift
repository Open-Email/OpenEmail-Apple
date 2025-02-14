import Foundation
import UniformTypeIdentifiers
import Observation
import OpenEmailCore
import Logging
import OpenEmailPersistence
import OpenEmailModel
import Utils
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

enum ComposeAction: Codable, Equatable, Hashable {
    // `id` is a temporary ID to make the instance of `ComposeAction` unique.
    // This allows multiple compose windows at the same time.
    case newMessage(id: UUID, authorAddress: String, readerAddress: String? = nil)
    case forward(id: UUID,  authorAddress: String, messageId: String)
    case reply(id: UUID,  authorAddress: String, messageId: String, quotedText: String?)
    case replyAll(id: UUID,  authorAddress: String, messageId: String, quotedText: String?)
    case editDraft(messageId: String)

    var isReplyAction: Bool {
        switch self {
        case .reply, .replyAll: return true
        default: return false
        }
    }
}

enum AttachmentsError: Error {
    case invalidImageData
    case fileStorageFailed
}

struct AttachedFileItem: Identifiable, Equatable {
    let url: URL
    let icon: OEImage
    let size: Int64?

    var id: URL { url }

    var exists: Bool { url.fileExists }

    init(url: URL) {
        self.url = url
        self.size = url.fileSize

        #if canImport(AppKit)
        let path = url.path(percentEncoded: false)
        self.icon = NSWorkspace.shared.icon(forFile: path)
        #else
        self.icon = UIImage.iconForFileURL(url)
        #endif
    }

    // initializer for previews
    init(url: URL, icon: OEImage, size: Int64?) {
        self.url = url
        self.icon = icon
        self.size = size
    }

    static func == (lhs: AttachedFileItem, rhs: AttachedFileItem) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
class ComposeMessageViewModel {
    @ObservationIgnored
    @Injected(\.client) private var client

    @ObservationIgnored
    @Injected(\.messagesStore) private var messagesStore

    @ObservationIgnored
    @Injected(\.contactsStore) private var contactsStore

    @ObservationIgnored
    @Injected(\.syncService) private var syncService

    @ObservationIgnored
    @Injected(\.attachmentsManager) private var attachmentsManager

    private static let dateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    var readers: [EmailAddress] = [] {
        didSet {
            updateDraft()
        }
    }

    var subject: String = "" {
        didSet {
            updateDraft()
        }
    }
    var subjectId: String? = nil

    var fullText: String = "" {
        didSet {
            updateDraft()
        }
    }

    var isBroadcast: Bool = false {
        didSet {
            updateDraft()
        }
    }

    var attachedFileItems: [AttachedFileItem] = []
    var action: ComposeAction

    var draftMessage: Message?

    var isSendButtonEnabled: Bool {
        hasAllDataForSending && (!readers.isEmpty || isBroadcast) // either have readers or it is a broadcast
    }

    var hasAllDataForSending: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty // non-empty subject
        && !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty // non-empty body
    }

    var canBroadcast: Bool {
        switch action {
        case .reply, .replyAll, .forward:
            false
        default:
            true
        }
    }

    var isSending: Bool = false
    var uploadProgress = 0.0
    private var sendTask: Task<Void, Error>?

    private var allContacts: [Contact] = []
    var contactSuggestions: [Contact] = []

    init(action: ComposeAction) {
        self.action = action

        Task {
            allContacts = (try? await contactsStore.allContacts()) ?? []
        }

        switch action {
        case .newMessage(_, _, let readerAddress):
            if let email = EmailAddress(readerAddress) {
                addReader(email)
            }

        case .forward(_, let localUserAddress, let messageId):
            Task {
                // TODO: error handling?
                try await setupForward(localUserAddress: localUserAddress, messageId: messageId)
            }

        case .reply(_, let authorAddress, let messageId, let quotedText):
            Task {
                await setupReply(authorAddress: authorAddress, messageId: messageId, quotedText: quotedText)
            }

        case .replyAll(_, let authorAddress, let messageId, let quotedText):
            Task {
                await setupReplyAll(authorAddress: authorAddress, messageId: messageId, quotedText: quotedText)
            }

        case .editDraft(let messageId):
            Task {
                Task {
                    await setupEditDraft(messageId: messageId)
                }
            }
        }
    }

    func updateIsSendButtonEnabled() {
        if !readers.isEmpty {
            self.readers = readers
        }
    }

    func send() async throws {
        guard let localUser = LocalUser.current else {
            return
        }

        sendTask = Task {
            defer {
                uploadProgress = 0
                isSending = false
            }

            isSending = true

            var messageId: String?
            if isBroadcast {
                messageId = try await client.uploadBroadcastMessage(
                    localUser: localUser,
                    subject: subject,
                    body: Data(fullText.bytes),
                    urls: attachedFileItems.map { $0.url }
                ) { [weak self] progress in
                    self?.uploadProgress = progress
                }
            } else {
                let emailAddresses = Array(readers)

                messageId = try await client.uploadPrivateMessage(
                    localUser: localUser,
                    subject: subject,
                    readersAddresses: emailAddresses,
                    body: Data(fullText.bytes),
                    urls: attachedFileItems.map { $0.url }
                ) { [weak self] progress in
                    self?.uploadProgress = progress
                }
            }

            if let messageId {
                // After sending, notify of the new messageId and trigger synchronizing
                await notifyNewOutgoingMessageId(messageId)
                await deleteDraft()
                await addMissingReadersToContacts()
            }
        }

        _ = try await sendTask?.value
    }

    func cancelSending() {
        sendTask?.cancel()
    }

    private func addMissingReadersToContacts() async {
        guard
            !isBroadcast,
            let localUser = LocalUser.current
        else {
            return
        }

        var missingContacts = [Contact]()

        for reader in readers {
            let address = reader.address
            if (try? await contactsStore.contact(address: address)) == nil {
                let profile = try? await client.fetchProfile(address: reader, force: true)
                let id = localUser.connectionLinkFor(remoteAddress: address)
                let contact = Contact(
                    id: id,
                    addedOn: Date(),
                    address: address,
                    receiveBroadcasts: true,
                    cachedName: profile?[.name],
                    cachedProfileImageURL: nil
                )
                missingContacts.append(contact)
            }
        }

        try? await contactsStore.storeContacts(missingContacts)
    }

    @MainActor
    private func setupForward(localUserAddress: String, messageId: String) async throws {
        guard
            let message = try? await messagesStore.message(id: messageId),
            let bodyText = message.body
        else {
            return
        }

        let authoredOn = Self.dateFormatter.string(from: message.authoredOn)

        var prefix = """
                    \n\n-------- Forwarded Message --------
                    Subject: \(message.subject)
                    Date:    \(authoredOn)
                    From:    \(message.author)
                    """
        if !message.readers.isEmpty {
            prefix += "\nTo:      \(message.readers.joined(separator: ", "))"
        }
        let fwdBody = prefix + "\n\n" + bodyText

        // TODO: how to handle attachments that are not downloaded?
        appendAttachedFiles(urls: message.attachments.compactMap {
            attachmentsManager.fileUrl(for: $0)
        })

        DispatchQueue.main.async {
            self.subject = message.subject
            self.fullText = fwdBody
        }
    }

    private func contactNameOrAddress(message: Message, authorAddress: String) async -> String {
        var contactNameOrAddress = message.author
        if message.author == authorAddress {
            if let authorName = UserDefaults.standard.profileName {
                contactNameOrAddress = authorName
            }
        } else {
            if
                let contact = try? await contactsStore.contact(address: message.author),
                let contactName = contact.cachedName
            {
                contactNameOrAddress = contactName
            }
        }

        return contactNameOrAddress
    }

    @MainActor
    private func setupReply(authorAddress: String, messageId: String, quotedText: String?) async {
        guard let message = try? await messagesStore.message(id: messageId) else {
            return
        }

        self.subject = message.subject
        self.subjectId = message.subjectId

        guard let replyAuthorAddress = EmailAddress(message.author) else {
            return
        }

        let contactNameOrAddress = await contactNameOrAddress(message: message, authorAddress: authorAddress)
        let authoredOn = Self.dateFormatter.string(from: message.authoredOn)

        let prefix = "On \(authoredOn), \(contactNameOrAddress) wrote:\n"
        self.fullText = prefix + wrapAndQuoteText(quotedText ?? message.body)

        let mReaders = message.readers

        if let authorEmailAddress = EmailAddress(authorAddress) {
            if replyAuthorAddress.address == authorEmailAddress.address {
                // If there is only one reader, and that reader is author, keep it
                if
                    mReaders.count == 1,
                    let firstAddress = mReaders.first,
                    let firstEmailAddress = EmailAddress(firstAddress),
                    firstEmailAddress.address == authorEmailAddress.address
                {
                    // do nothing
                } else {
                    // Reply own message implies Reply-All
                    copyReadersFromMessage(message, author: authorEmailAddress)
                }
            } else {
                addReader(replyAuthorAddress, ignoreAddress: authorEmailAddress)
            }
        }
    }

    @MainActor
    private func setupReplyAll(authorAddress: String, messageId: String, quotedText: String?) async {
        guard let message = try? await messagesStore.message(id: messageId) else {
            return
        }

        self.subject = message.subject
        self.subjectId = message.subjectId

        let contactNameOrAddress = await contactNameOrAddress(message: message, authorAddress: authorAddress)
        let authoredOn = Self.dateFormatter.string(from: message.authoredOn)

        let prefix = "On \(authoredOn), \(contactNameOrAddress) wrote:\n"
        self.fullText = prefix + wrapAndQuoteText(quotedText ?? message.body)

        if let localAuthorAddress = EmailAddress(authorAddress) {
            // Reply to author and all recipients, except self if present
            if let messageAuthorAddress = EmailAddress(message.author) {
                addReader(messageAuthorAddress, ignoreAddress: localAuthorAddress)
            }
            copyReadersFromMessage(message, author: localAuthorAddress)
        }
    }

    @MainActor
    private func setupEditDraft(messageId: String) async {
        guard let draftMessage = try? await messagesStore.message(id: messageId) else {
            return
        }

        self.draftMessage = draftMessage

        self.subject = draftMessage.subject
        self.subjectId = draftMessage.subjectId
        self.fullText = draftMessage.body ?? ""
        self.isBroadcast = draftMessage.isBroadcast

        if let localAuthorAddress = LocalUser.current?.address {
            copyReadersFromMessage(draftMessage, author: localAuthorAddress)
        }

        appendAttachedFiles(urls: draftMessage.draftAttachmentUrls)
    }

    func addReader(_ address: EmailAddress, ignoreAddress: EmailAddress? = nil) {
        if address.address == ignoreAddress?.address {
            return
        }
        if isReaderPresent(address) {
            return
        }
        readers.append(address)
        updateDraft()
    }

    private func isReaderPresent(_ addr: EmailAddress) -> Bool {
        return readers.first(where: { $0.address == addr.address }) != nil
    }

    private func copyReadersFromMessage(_ message: Message, author: EmailAddress) {
        for reader in message.readers {
            if let readerAddress = EmailAddress(reader) {
                addReader(readerAddress, ignoreAddress: author)
            }
        }
    }

    private func wrapAndQuoteText(_ text: String?, maxLength: Int = 80, prefix: String = "> ", intro: String? = nil) -> String {
        guard let text else {
            return ""
        }

        var result = ""
        var line = ""

        func processParagraph(_ paragraph: String) {
            if paragraph.isEmpty {
                // Directly add prefix for empty paragraphs
                result += prefix + "\n"
            } else {
                // Check if the paragraph already starts with the prefix
                let isPrefixed = paragraph.hasPrefix(prefix)
                let currentPrefix = isPrefixed ? "" : prefix

                paragraph.split(separator: " ", omittingEmptySubsequences: false).forEach { word in
                    let space = line.isEmpty ? "" : " "
                    if line.count + word.count + space.count > maxLength && !isPrefixed {
                        // Add the current line to the result
                        if !line.isEmpty {
                            result += currentPrefix + line + "\n"
                        }
                        line = String(word)
                    } else {
                        line += space + word
                    }
                }
                // Add the last line of the paragraph to the result
                if !line.isEmpty {
                    result += currentPrefix + line + "\n"
                }
                line = "" // Reset for the next paragraph
            }
        }

        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .forEach {
                processParagraph($0)
            }

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if let introText = intro, !introText.isEmpty {
            result = introText + "\n" + result
        }

        return result + "\n\n"
    }

    // MARK: - Attachments

    func appendAttachedFiles(urls: [URL]) {
        for url in urls {
            if !attachedFileItems.contains(where: { url == $0.url }) {
                let item = AttachedFileItem(url: url)
                attachedFileItems.append(item)
            }
        }

        updateDraft()
    }

#if os(iOS)
    private var addedImageCount = 0
    func addAttachmentItem(from imageData: Data) async throws {
        guard
            let image = UIImage(data: imageData)
        else {
            Log.error("Could not get image data")
            throw AttachmentsError.invalidImageData
        }

        let filename = "image\(addedImageCount)"

        let url: URL

        if
            let utTypeString = image.cgImage?.utType,
            let utType = UTType(utTypeString as String)
        {
            url = try saveTemporaryImage(data: imageData, utType: utType, filename: filename)
        } else {
            // fall back to png
            Log.warning("Could not determine type of image – falling back to PNG")

            guard let pngData = image.pngData() else {
                Log.error("Could not get PNG data")
                throw AttachmentsError.invalidImageData
            }

            url = try saveTemporaryImage(data: pngData, utType: .png, filename: filename)
        }

        addedImageCount += 1

        let item = AttachedFileItem(url: url)
        attachedFileItems.append(item)
    }
#endif
    
    func removeAttachedFileItem(item: AttachedFileItem) {
        if let index = attachedFileItems.firstIndex(where: { item.url == $0.url }) {
            if item.url.isInTemporaryDirectory {
                try? FileManager.default.removeItem(atPath: item.url.path())
            }
            attachedFileItems.remove(at: index)
        }

        updateDraft()
    }

    private func saveTemporaryImage(data: Data, utType: UTType, filename: String) throws -> URL {
        let fm = FileManager.default

        let messageId = draftMessage?.id ?? ""

        let tempUrl = fm.temporaryDirectory
            .appendingPathComponent("attachments", isDirectory: true)
            .appendingPathComponent(messageId, isDirectory: true)

        var fileUrl = tempUrl.appendingPathComponent(filename)
        if let preferredFilenameExtension = utType.preferredFilenameExtension {
            fileUrl = fileUrl.appendingPathExtension(preferredFilenameExtension)
        }

        try fm.createDirectory(at: tempUrl, withIntermediateDirectories: true)
        if fm.createFile(atPath: fileUrl.path(), contents: data) {
            Log.debug("successfully stored temporary attachment")
            return fileUrl
        } else {
            throw AttachmentsError.fileStorageFailed
        }
    }

    // MARK: - Drafts

    func notifyNewOutgoingMessageId(_ messageId: String) async {
        await syncService.appendOutgoingMessageId(messageId)
    }

    func updateDraft() {
        Task {
            if draftMessage == nil {
                draftMessage = .draft()
            }

            guard var draftMessage else { return }

            draftMessage.subject = subject
            draftMessage.body = fullText
            draftMessage.readers = readers.map { $0.address }
            draftMessage.draftAttachmentUrls = attachedFileItems.map { $0.url }
            draftMessage.isBroadcast = isBroadcast

            if draftMessage.isEmptyDraft {
                await deleteDraft()
            } else {
                do {
                    try await messagesStore.storeMessage(draftMessage)
                } catch {
                    Log.error("Could not save draft: \(error)")
                }
            }
        }
    }

    func deleteDraft() async {
        guard let draftMessage else {
            return
        }
        
        try? await messagesStore.deleteMessage(id: draftMessage.id)
    }

    func loadContactSuggestions(for inputText: String) async {
        let searchString = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard searchString.count >= 3 else {
            contactSuggestions = []
            return
        }

        contactSuggestions = allContacts.filter { contact in
            guard let address = EmailAddress(contact.address) else {
                return false
            }

            guard !readers.contains(address) else {
                return false
            }

            return contact.address.localizedStandardContains(searchString) || (contact.cachedName ?? "").localizedStandardContains(searchString)
        }
    }
}

private extension URL {
    var isInTemporaryDirectory: Bool {
        path.hasPrefix(FileManager.default.temporaryDirectory.path)
    }
}

private extension Message {
    var isEmptyDraft: Bool {
        return subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        readers.isEmpty &&
        draftAttachmentUrls.isEmpty
    }
}

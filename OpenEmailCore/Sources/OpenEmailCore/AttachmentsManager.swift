import Foundation
import OpenEmailModel
import Utils
import Observation
import Logging

@Observable
public class AttachmentDownloadProgress: Identifiable, Equatable {
    public static func == (lhs: AttachmentDownloadProgress, rhs: AttachmentDownloadProgress) -> Bool {
        lhs.id == rhs.id
        && lhs.didFinish == rhs.didFinish
        && lhs.didCancel == rhs.didCancel
    }
    
    public fileprivate(set) var attachment: Attachment
    public fileprivate(set) var progress: Double = 0
    public fileprivate(set) var didFinish = false
    public fileprivate(set) var didCancel = false
    public fileprivate(set) var error: Error?

    public private(set) var cancel: () -> Void

    public var id: String {
        attachment.id
    }

    fileprivate init(attachment: Attachment, cancel: @escaping () -> Void) {
        self.attachment = attachment
        self.cancel = cancel
    }
}

public protocol AttachmentsManaging {
    /// Returns the local url of the attachment
    /// Returns `nil` if the attachment has not yet been downloaded.
    func fileUrl(for attachment: Attachment) -> URL?

    /// Returns a download progress object with information about the ongoing download.
    /// Returns `nil` if the file has already been downloaded.
    @discardableResult
    func download(attachment: Attachment) -> AttachmentDownloadProgress?

    /// All ongoing downloads
    var downloadInfos: [Attachment.ID: DownloadInfo] { get }
}

public typealias AttachmentDownloadTask = Task<(), Never>

public struct DownloadInfo: Equatable {
    public var progress: AttachmentDownloadProgress
    public var task: AttachmentDownloadTask
}

@Observable
public final class AttachmentsManager: AttachmentsManaging {
    @ObservationIgnored
    private let client = DefaultClient.shared

    // queue to synchronize thread safe access to the downloads dictionary
    private let queue = DispatchQueue(label: "attachments", qos: .background)

    // stores active download progress by attachment id
    private(set) public var downloadInfos: [Attachment.ID: DownloadInfo] = [:]

    public static let shared = AttachmentsManager()

    private init() {}

    public func fileUrl(for attachment: Attachment) -> URL? {
        guard
            let localUser = LocalUser.current
        else {
            return nil
        }

        let fm = FileManager.default

        let fileUrl = fm.messageFolderURL(userAddress: localUser.address.address, messageID: attachment.parentMessageId)
            .appending(path: attachment.filename)

        if fm.fileExists(atPath: fileUrl.path(percentEncoded: false)) {
            return fileUrl
        }

        // file does not exist
        return nil
    }
    
    @discardableResult
    public func download(attachment: Attachment) -> AttachmentDownloadProgress? {
        guard let localUser = LocalUser.current else { return nil }
        guard fileUrl(for: attachment) == nil else {
            Log.debug("\(attachment.filename) already downloaded")
            return nil
        }

        // check if ongoing download already exists
        var download: DownloadInfo?
        queue.sync {
            download = downloadInfos[attachment.id]
        }

        // Only return an ongoing download if it has not been canceled or did not fail.
        // In those cases a new download should be initiated.
        if let download, download.progress.didCancel == false, download.progress.error == nil {
            Log.debug("download for \(attachment.filename) already in progress")
            return download.progress
        }

        let progress = AttachmentDownloadProgress(attachment: attachment) { [unowned self] in
            cancelDownload(for: attachment)
        }
        let task = Task.detached { [unowned self] in
            do {
                try await client.downloadFileAttachment(
                    messageIds: attachment.fileMessageIds,
                    parentId: attachment.parentMessageId,
                    localUser: localUser,
                    filename: attachment.filename
                )
                finishDownload(for: attachment)
            } catch {
                Log.error("Error downloading attachment: \(error)")
                progress.error = error
                progress.didFinish = true
            }
        }

        queue.sync {
            downloadInfos[attachment.id] = DownloadInfo(progress: progress, task: task)
        }

        return progress
    }

    // TODO: implement canceling in Downloader class
    private func cancelDownload(for attachment: Attachment) {
        queue.sync {
            let download = downloadInfos[attachment.id]
            download?.progress.didCancel = true
            download?.task.cancel()
        }
    }

    private func finishDownload(for attachment: Attachment) {
        queue.sync {
            let download = downloadInfos[attachment.id]
            download?.progress.didFinish = true
            download?.progress.progress = 1
            downloadInfos[attachment.id] = nil
        }
    }
}

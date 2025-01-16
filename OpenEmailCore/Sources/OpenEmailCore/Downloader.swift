import Foundation
import Logging

class Downloader {
    private let session = URLSession(configuration: .default)
    private var retries = 3 // Number of retries
    private let retryDelay: TimeInterval = 2 // Delay in seconds

    func downloadFile(from url: URL, to destinationURL: URL, accessKey: [UInt8]? = nil, localUser: LocalUser) async throws {
        try await attemptDownload(from: url, to: destinationURL, accessKey: accessKey, localUser: localUser, retryCount: retries)
    }

    // TODO: add url session delegate to track download progress
    // TODO: add support for cancellation

    private func attemptDownload(from url: URL, to destinationURL: URL, accessKey: [UInt8]?, localUser: LocalUser, retryCount: Int) async throws {
        let authNonce: String
        do {
            authNonce = try Nonce(localUser: localUser).sign(host: url.host()!)
        } catch {
            throw error
        }

        var request = URLRequest(url: url)
        request.addValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)

        var tempLocationURL: URL
        do {
            let (location, response) = try await session.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                Log.error("got errors status code: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            tempLocationURL = location
        } catch {
            Log.error("error downloding file: \(error)")
            if retryCount > 0 {
                Log.debug(" retrying (retryCount=\(retryCount))")
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                return try await attemptDownload(from: url, to: destinationURL, accessKey: accessKey, localUser: localUser, retryCount: retryCount - 1)
            } else {
                throw error
            }
        }

        // do we need the accessKey of the file message here or can we use the one from the  parent message?

        if let accessKey {
            try Crypto.decryptFile_xchacha20poly1305(inputURL: tempLocationURL, outputURL: destinationURL, secretkey: accessKey)
        } else {
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.moveItem(at: tempLocationURL, to: destinationURL)
        }
    }
}

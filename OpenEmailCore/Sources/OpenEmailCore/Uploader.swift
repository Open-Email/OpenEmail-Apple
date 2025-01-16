import Foundation
import Utils
import Logging

class Uploader {
    private let session = URLSession(configuration: .default)
    private var retries = 3 // Number of retries
    private let retryDelay: TimeInterval = 2 // Delay in seconds
    private let localUser: LocalUser

    init(localUser: LocalUser) {
        self.localUser = localUser
    }

    func uploadMessageToAgent(agentHostname: String, envelope: Envelope, uploadData: [UInt8]) async throws {
        try await attemptUpload(to: agentHostname, localUser: localUser, envelope: envelope, uploadData: uploadData, retryCount: retries)
    }

    private func attemptUpload(to agentHostname: String, localUser: LocalUser, envelope: Envelope, uploadData: [UInt8], retryCount: Int) async throws {
        guard let url = URL(string: "https://\(agentHostname)/home/\(localUser.address.hostPart)/\(localUser.address.localPart)/messages") else {
            throw ClientError.invalidEndpoint
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(String(uploadData.count), forHTTPHeaderField: "Content-Length")
        let nonce: String
        do {
            nonce = try Nonce(localUser: localUser).sign(host: url.host!)
        } catch {
            throw error
        }
        urlRequest.setValue(nonce, forHTTPHeaderField: AUTHORIZATION_HEADER)

        for (key, value) in envelope.envelopeHeadersMap {
            if key.hasPrefix(HEADER_PREFIX) {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        do {
            let (data, response) = try await session.upload(for: urlRequest, from: Data(uploadData))
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClientError.invalidHTTPResponse
            }

            // silence a cache warning message that is logged after uploading big files
            session.configuration.urlCache?.removeAllCachedResponses()

            if httpResponse.statusCode == 200 {
                // Log success or perform further success handling here
                Log.info("File uploaded successfully.")
            } else {
                // Handle server error response
                let responseString = String(data: data, encoding: .utf8)
                Log.error("The file could not be uploaded. Server response:", context: responseString)
                throw ClientError.uploadFailure
            }
        } catch {
            if retryCount > 0 {
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                try await attemptUpload(to: agentHostname, localUser: localUser, envelope: envelope, uploadData: uploadData, retryCount: retryCount - 1)
            } else {
                throw error
            }
        }
    }
}

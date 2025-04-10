import Foundation
import OpenEmailPersistence
import OpenEmailModel
import Logging
import Utils

private let MAX_MESSAGE_SIZE: UInt64 = 64*1024*1024
private let MAX_MAIL_AGENTS_CONSIDERED = 3
public let AUTHORIZATION_HEADER = "Authorization"
private let NOTIFICATION_ORIGIN_HEADER = "Notifier-Encrypted"
public let ENCRYPTED_LINK_HEADER = "Link-Encrypted"
private let DEFAULT_MAIL_SUBDOMAIN = "mail"
private let WELL_KNOWN_URI = ".well-known/mail.txt"
private let CACHE_EXPIRY = 60*60
public let PROFILE_IMAGE_SIZE = CGSize(width: 800, height: 800)

struct DelegatedHostsCache {
    let result: [String]
    let timestamp: Date
}


extension DelegatedHostsCache {
    func isExpired() -> Bool {
        let expirationPeriod = TimeInterval(CACHE_EXPIRY)
        return Date().timeIntervalSince(timestamp) > expirationPeriod
    }
}

enum ClientError: Error {
    case noHostsAvailable
    case registrationAccountAlreadyExists
    case invalidEndpoint
    case invalidLink
    case invalidFileURL
    case invalidHTTPResponse
    case invalidContentHeaders
    case invalidReaders
    case inaccessibleReaders
    case uploadFailure
    case checksumMismatched
    case invalidProfile
    case requestFailed
    // Other error cases can be added here as needed
}

public extension NSNotification.Name {
    static let profileImageUpdated = NSNotification.Name("profileImageUpdated")
}

public protocol Client {
    // Auth
    func authenticate(emailAddress: EmailAddress, privateEncryptionKey: String, privateSigningKey: String) async throws -> (LocalUser?, [String])
    
    // Registration
    func generateLocalUser(address: String, name: String?) throws -> LocalUser
    func registerAccount(user: LocalUser, fullName: String?) async throws
    func lookupAddressAvailability(address: EmailAddress) async throws -> Bool
    func lookupHostsDelegations(address: EmailAddress) async throws -> [String]
    
    // Notifications
    func fetchNotifications(localUser: LocalUser) async throws
    func notifyReaders(readersAddresses: [EmailAddress], localUser: LocalUser) async throws
    
    // Messages
    func executeNotifications(localUser: LocalUser) async throws -> [String]
    func fetchRemoteMessages(localUser: LocalUser, authorProfile: Profile) async throws
    func fetchRemoteBroadcastMessages(localUser: LocalUser, authorProfile: Profile) async throws
    func fetchLocalMessages(localUser: LocalUser, localProfile: Profile) async throws -> [String]
    func uploadPrivateMessage(localUser: LocalUser, subject: String, readersAddresses: [EmailAddress], body: Data, urls: [URL], progressHandler: @escaping (Double) -> Void) async throws -> String?
    func uploadBroadcastMessage(localUser: LocalUser, subject: String, body: Data, urls: [URL], progressHandler: @escaping (Double) -> Void) async throws -> String?
    func recallAuthoredMessage(localUser: LocalUser, messageId: String) async throws
    func fetchMessageDeliveryInformation(localUser: LocalUser, messageId: String) async throws -> [(String, Date)]?
    func downloadFileAttachment(messageIds: [String], parentId: String, localUser: LocalUser, filename: String) async throws
    
    // Profile
    func fetchProfile(address: EmailAddress, force: Bool) async throws -> Profile?
    func fetchProfileImage(address: EmailAddress, force: Bool) async throws -> Data?
    func uploadProfile(localUser: LocalUser, profile: Profile) async throws
    func uploadProfileImage(localUser: LocalUser, imageData: Data) async throws
    func deleteProfileImage(localUser: LocalUser) async throws
    func isAddressInContacts(localUser: LocalUser, address: EmailAddress) async throws -> Bool
    
    // Contacts
    func getLinks(localUser: LocalUser) async throws -> [Link]?
    func updateBroadcastsForContact(localUser: LocalUser, address: EmailAddress, allowBroadcasts: Bool) async throws
    func storeContact(localUser: LocalUser, address: EmailAddress) async throws
    func fetchContacts(localUser: LocalUser) async throws -> [EmailAddress]
    func deleteContact(localUser: LocalUser, address: EmailAddress) async throws
    func syncContacts(localUser: LocalUser) async throws
}


public class DefaultClient: Client {
    public static let shared = DefaultClient()
    private var delegatedHostsCache = [String: DelegatedHostsCache]()
    private let profileCache = ProfileCache()
    private let profileImageCache = ProfileImageCache()
    
    private let contactsStore: ContactStoring
    private let messagesStore: MessageStoring
    private let notificationsStore: NotificationStoring
    
    private var imageRequestTimestamps = AtomicDictionary<URL, Date>()
    private static let imageRequestCooldown = TimeInterval(15 * 60) // 15 minutes
    
    init(
        messagesStore: MessageStoring = PersistedStore.shared,
        contactsStore: ContactStoring = PersistedStore.shared,
        notificationsStore: NotificationStoring = PersistedStore.shared
    ) {
        URLSession.shared.configuration.timeoutIntervalForRequest = 30
        URLSession.shared.configuration.timeoutIntervalForResource = 30
        
        self.messagesStore = messagesStore
        self.contactsStore = contactsStore
        self.notificationsStore = notificationsStore
    }
    
    typealias Handler<T> = (String) async throws -> T?
    
    // MARK: - Hosts Lookup
    
    private func withAllRespondingDelegatedHosts<T>(address: EmailAddress, handler: @escaping Handler<T>) async throws -> [T]? {
        let hosts = try await lookupHostsDelegations(address: address)
        guard !hosts.isEmpty else {
            throw ClientError.noHostsAvailable
        }
        
        return try await withThrowingTaskGroup(of: T?.self) { group in
            for host in hosts {
                group.addTask {
                    try await handler(host)
                }
            }
            
            var results = [T]()
            for try await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            return results
        }
    }
    
    private func withFirstRespondingDelegatedHost<T>(address: EmailAddress, handler: @escaping Handler<T>) async throws -> T? {
        let hosts = try await lookupHostsDelegations(address: address)
        guard !hosts.isEmpty else { throw ClientError.noHostsAvailable }
        
        return try await withThrowingTaskGroup(of: T?.self) { group in
            for host in hosts {
                group.addTask {
                    try await handler(host)
                }
            }
            
            // Wait for the first successful result, then cancel others
            while let result = try await group.next() {
                if let result = result {
                    group.cancelAll() // Stop all other tasks
                    return result
                }
            }
            return nil
        }
    }
    
    // TODO: the response in well known file may split roles of hosts so some hosts
    // TODO: are only for recieving notifications, some for storing messages, some for hosting profiles.
    // TODO: This is easily backwards compatible, if we add "; role=notify,forward,profile" postfix.
    
    public func lookupHostsDelegations(address: EmailAddress) async throws -> [String] {
        if let cacheEntry = delegatedHostsCache[address.hostPart], !cacheEntry.isExpired(), !cacheEntry.result.isEmpty {
            return cacheEntry.result
        }
        
        let defaultMailAgentHostname = "\(DEFAULT_MAIL_SUBDOMAIN).\(address.hostPart)"
        guard
            let wellKnownHosts = try await lookupWellKnownDelegations(hostname: address.hostPart, verifyHostDelegation: false),
            wellKnownHosts.count > 0
        else {
            // Check if listed hosts are responsible for the mail accounts in question.
            let result: [String]
            if try await isDelegatedFor(mailAgentHostname: defaultMailAgentHostname, domain: address.hostPart) {
                result = [defaultMailAgentHostname]
                delegatedHostsCache[address.hostPart] = DelegatedHostsCache(result: result, timestamp: Date())
                return result
            }
            return []
        }
        return wellKnownHosts
    }
    
    
    private func lookupWellKnownDelegations(hostname: String, verifyHostDelegation: Bool = true) async throws -> [String]? {
        guard let url = URL(string: "https://\(hostname)/\(WELL_KNOWN_URI)") else {
            throw ClientError.invalidEndpoint
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 /* OK */
            else {
                return nil
            }
            
            if let contentString = String(data: data, encoding: .utf8) {
                let hostsDelegations = Array(contentString
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                             // Ignore comments
                    .filter { !$0.hasPrefix("#") }
                                             // Ignore invalid hostnames
                    .filter { isValidHostname(hostname: $0) }
                                             // Ignore duplicates
                    .unique()
                                             // Cutoff the list
                    .prefix(MAX_MAIL_AGENTS_CONSIDERED))
                
                if verifyHostDelegation {
                    // Check if hosts are really responsible for the domain
                    var verifiedHostsDelegations: [String] = []
                    try await hostsDelegations.asyncForEach {
                        if try await isDelegatedFor(mailAgentHostname: $0, domain: hostname) {
                            verifiedHostsDelegations.append($0)
                        }
                    }
                    return verifiedHostsDelegations
                }
                return hostsDelegations
            }
        } catch {
            return nil
        }
        return nil
    }
    
    /**
     Checks delegation of a mail agent for a given email domain.
     
     It does so by querying the home host's Email v2 service configuration file at `https://HOST_PART/.well-known/mail.txt`.
     
     - Parameters:
     - mailAgentHostname: The mail agent hostname to query
     - domain: Email address domain part
     
     - Returns: A boolean value indicating whether the agent is responsible for the given email domain
     */
    private func isDelegatedFor(mailAgentHostname: String, domain: String) async throws -> Bool {
        guard !domain.isEmpty else { return false }
        guard let url = URL(string: "https://\(mailAgentHostname)/mail/\(domain)") else {
            throw ClientError.invalidEndpoint
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "HEAD"
        
        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        return false
    }
    
    
    private func isValidHostname(hostname: String) -> Bool {
        guard !hostname.isEmpty else { return false }
        
        var isValid = false
        let semaphore = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "hostname.validation.queue", qos: .userInitiated)
        
        queue.async {
            let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
            var streamError = CFStreamError()
            let success = CFHostStartInfoResolution(host, .addresses, &streamError)
            isValid = success
            semaphore.signal()
        }
        
        semaphore.wait()
        return isValid
    }
    
    
    // MARK: - Authentication & Registrations
    
    public func generateLocalUser(address: String, name: String?) throws -> LocalUser {
        let (privateEncryptionKey, publicEncryptionKey, publicEncryptionKeyId) = Crypto.generateEncryptionKeys()
        let (privateSigningKey, publicSigningKey) = Crypto.generateSigningKeys()
        return try LocalUser(address: address, name: name, privateEncryptionKeyBase64:privateEncryptionKey, publicEncryptionKeyBase64: publicEncryptionKey, publicEncryptionKeyId: publicEncryptionKeyId, privateSigningKeyBase64: privateSigningKey, publicSigningKeyBase64: publicSigningKey)
    }
    
    public func registerAccount(user: LocalUser, fullName: String?) async throws {
        _ = try await withFirstRespondingDelegatedHost(address: user.address) { hostname -> Void in
            let authNonce = try Nonce(localUser: user).sign(host: hostname)
            guard let url = URL(string: "https://\(hostname)/account/\(user.address.hostPart)/\(user.address.localPart)") else {
                throw ClientError.invalidEndpoint
            }
            
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
            urlRequest.httpMethod = "POST"
            
            // TODO: More data can be posted here. Signing-Key & Updated are the only required ones.
            let currentDate = Date()
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            
            let postData = """
            Name: \(fullName ?? "")
            Encryption-Key: id=\(user.publicEncryptionKeyId); algorithm=\(Crypto.ANONYMOUS_ENCRYPTION_CIPHER); value=\(user.publicEncryptionKeyBase64)
            Signing-Key: algorithm=\(Crypto.SIGNING_ALGORITHM); value=\(user.publicSigningKeyBase64)
            Updated: \(dateFormatter.string(from: currentDate))
            """
            
            if let data = postData.data(using: .utf8) {
                urlRequest.httpBody = data
                let (_, response) = try await URLSession.shared.data(for: urlRequest)
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200  {
                        if httpResponse.statusCode == 409 {
                            throw RegistrationError.accountAlreadyExists
                        }
                        throw RegistrationError.provisioningError
                    } else {
                        return
                    }
                }
            } else {
                throw RegistrationError.provisioningError
            }
        }
    }
    
    public func lookupAddressAvailability(address: EmailAddress) async throws -> Bool {
        if let responses = try await withAllRespondingDelegatedHosts(address: address, handler: { hostname -> Bool in
            guard let url = URL(string: "https://\(hostname)/account/\(address.hostPart)/\(address.localPart)") else {
                throw ClientError.invalidEndpoint
            }
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "HEAD"
            
            do {
                let (_, response) = try await URLSession.shared.data(for: urlRequest)
                if let httpResponse = response as? HTTPURLResponse {
                    return httpResponse.statusCode == 200
                }
            }
            return false
        }) {
            // All responses must be true
            return responses.reduce(true) { $0 && $1 }
        }
        return false
    }
    
    public func authenticate(emailAddress: EmailAddress, privateEncryptionKey: String, privateSigningKey: String) async throws -> (LocalUser?, [String]) {
        // In order to authenticate, the public profile is needed of the
        // authenticating user as it contains the public key. If the authentication
        // succeeds, the public keys are taken over locally. If profile cannot
        // be fetched from remote, the authentication is not possible.
        
        guard let profile = try await fetchProfile(address: emailAddress, force: false) else {
            return (nil, [])
        }
        
        if
            let publicEncryptionKey = profile[.encryptionKey],
            let publicEncryptionKeyId = profile.encryptionKeyId,
            let publicSigningKey = profile[.signingKey]
        {
            let localUser = try LocalUser(address: emailAddress.address, name: profile[.name], privateEncryptionKeyBase64: privateEncryptionKey, publicEncryptionKeyBase64: publicEncryptionKey, publicEncryptionKeyId: publicEncryptionKeyId, privateSigningKeyBase64: privateSigningKey, publicSigningKeyBase64: publicSigningKey)
            
            let authResults = try await multiHostAuthentication(user: localUser)
            let allHostsAuthenticate = authResults.allSatisfy { (hostname, authSuccess) in
                return authSuccess
            }
            if allHostsAuthenticate {
                return (localUser, [])
            }
            
            // Some hosts fail authentication
            let atLeastOneAuthenticates = authResults.contains(where: { (hostname, authSuccess) in
                return authSuccess
            })
            if atLeastOneAuthenticates {
                let failingHosts = authResults.filter({ (hostname, authSuccess) in
                    return !authSuccess
                }).map { (hostname, authSuccess) in
                    return hostname
                }
                return (localUser, failingHosts)
            }
            
        }
        return (nil, [])
    }
    
    private func multiHostAuthentication(user: LocalUser) async throws -> [(String, Bool)] {
        if let responses = try await withAllRespondingDelegatedHosts(address: user.address, handler: { hostname -> (String, Bool) in
            let authNonce = try Nonce(localUser: user).sign(host: hostname)
            let authenticates = try await self.tryHostAuthentication(agentHostname: hostname, address: user.address, nonce: authNonce)
            return (hostname, authenticates)
        }) {
            return responses
        }
        return []
    }
    
    private func tryHostAuthentication(agentHostname: String, address: EmailAddress, nonce: String) async throws -> Bool {
        guard let url = URL(string: "https://\(agentHostname)/home/\(address.hostPart)/\(address.localPart)") else {
            throw ClientError.invalidEndpoint
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue(nonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
        urlRequest.httpMethod = "HEAD"
        
        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200 /* OK */
        }
        return false
    }
    
    
    // MARK: Notifications
    
    public func fetchNotifications(localUser: LocalUser) async throws {
        if let responses = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname -> [String] in
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            if let notifications = try await self.fetchNotificationsFromAgent(agentHostname: hostname, address: localUser.address, nonce: authNonce) {
                return notifications
            }
            return []
        }) {
            var verifiedNotifications: [OpenEmailModel.Notification] = []
            for notificationLine in responses.flatMap({ $0 }).unique() {
                do {
                    if let notification = try await verifyNotification(notificationLine: notificationLine, localUser: localUser) {
                        verifiedNotifications.append(notification)
                    }
                } catch {
                    // Address cannot be decrypted or profile cannot be fetched.
                    // This could indicate a local problem too. Notification is not actionable.
                    // This should not prevent other notifications to be checked.
                    Log.error("Address cannot be decrypted or profile cannot be fetched.", context: error)
                }
            }
            if !verifiedNotifications.isEmpty {
                for notification in verifiedNotifications {
                    if let address = EmailAddress(notification.address) {
                        if UserDefaults.standard.trustedDomains.contains(address.hostPart) {
                            try await upsertLocalContact(localUser: localUser, address: address)
                        }
                    }
                }
                try await notificationsStore.storeNotifications(verifiedNotifications)
            }
            
        }
    }
    
    private func fetchNotificationsFromAgent(agentHostname: String, address: EmailAddress, nonce: String) async throws -> [String]? {
        guard let url = URL(string: "https://\(agentHostname)/home/\(address.hostPart)/\(address.localPart)/notifications") else {
            throw APIError.badEndpoint
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue(nonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 /* OK */ else {
                return nil
            }
            if let contentString = String(data: data, encoding: .utf8) {
                let lines = contentString.components(separatedBy: CharacterSet.newlines)
                let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .unique()
                return trimmedLines
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func verifyNotification(notificationLine: String, localUser: LocalUser) async throws -> OpenEmailModel.Notification? {
        let notificationParts = notificationLine
            .split(separator: ",", maxSplits: 4)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let id = notificationParts[0]
        let link = notificationParts[1]
        let signingKeyFP = notificationParts[2]
        let encryptedNotifier = notificationParts[3]
        
        if let notification = try await notificationsStore.notification(id: id), notification.isProcessed {
            // An existing notification with same ID may exists and it
            // may have been executed already or not.
            Log.info("notification with same id was already processed")
            return nil
        }
        
        // If the encryption key was updated in the mean time, then the decryption will fail.
        // The right process of encryption key rotation will avoid that. All notifications should
        // be fetched before updating keys.
        
        guard let notifierAddress = try? Crypto.decryptAnonymous(cipherText: encryptedNotifier, privateKey: localUser.privateEncryptionKey, publicKey: localUser.publicEncryptionKey) else {
            Log.info("notification cannot be decrypted, skipping")
            return nil
        }
        
        // Basic verification: address and link match.
        guard let sourceAddress = String(bytes: notifierAddress, encoding: .ascii),
              let address = EmailAddress(sourceAddress) else {
            Log.error("Unable to decode notification address of link \(link). skipping")
            return nil
        }
        
        guard let profile = try await fetchProfile(address: address, force: false) else {
            // We won't handle this notification until the profile is available
            Log.error("Unable to fetch profile for notification of \(sourceAddress). skipping")
            return nil
        }
        
        guard localUser.connectionLinkFor(remoteAddress: address.address) == link else {
            Log.error("Notification of \(sourceAddress) does not pass link checks, skipping")
            return nil
        }
        
        // Check fingeprint of signing key now
        var fpMatchFound = false
        if let profileSigningKeyB64 = profile[.signingKey],
           let profileSigningKey = Crypto.base64decode(profileSigningKeyB64),
           signingKeyFP == Crypto.publicKeyFingerprint(publicKey: profileSigningKey) {
            fpMatchFound = true
        }
        // The signing key does not match actual signing key. Try previous key if available
        if !fpMatchFound,
           let previousSigningKeyB64 = profile[.lastSigningKey],
           let previousSigningKey = Crypto.base64decode(previousSigningKeyB64),
           signingKeyFP == Crypto.publicKeyFingerprint(publicKey: previousSigningKey) {
            fpMatchFound = true
        }
        
        if fpMatchFound {
            // The embedded address is accepted only after the notification is verified
            return OpenEmailModel.Notification(id: id, receivedOn: .now, link: link, address: address.address, authorFingerPrint: signingKeyFP)
        }
        return nil
    }
    
    private func notifyAddress(localUser: LocalUser, remoteAddress: EmailAddress) async throws {
        let connectionLink = localUser.connectionLinkFor(remoteAddress: remoteAddress.address)
        
        guard let remoteProfile = try await fetchProfile(address: remoteAddress, force: false),
              let encryptionKeyStr = remoteProfile[.encryptionKey],
              let encryptionKey = Crypto.base64decode(encryptionKeyStr),
              let encryptionKeyId = remoteProfile.encryptionKeyId else {
            
            return
        }
        let encryptedLocalAddress = try Crypto.encryptAnonymous(data: localUser.address.address.bytes, publicKey: encryptionKey)
        let encodedEncryptedAddress = Crypto.base64encode(encryptedLocalAddress)
        
        _ = try await withAllRespondingDelegatedHosts(address: remoteAddress, handler: { hostname -> Void in
            let nonce = try Nonce(localUser: localUser).sign(host: hostname)
            try await self.notifyAddressAgent(agentHostname: hostname, localUser: localUser, remoteAddress: remoteAddress, link: connectionLink, encryptedBody: encodedEncryptedAddress, encryptionKeyId: encryptionKeyId, nonce: nonce)
        })
    }
    
    private func notifyAddressAgent(agentHostname: String, localUser: LocalUser, remoteAddress: EmailAddress, link: String, encryptedBody: String, encryptionKeyId: String, nonce: String) async throws {
        guard let url = URL(string: "https://\(agentHostname)/mail/\(remoteAddress.hostPart)/\(remoteAddress.localPart)/link/\(link)/notifications") else {
            throw ClientError.invalidEndpoint
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        urlRequest.setValue(nonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
        urlRequest.httpBody = encryptedBody.data(using: .ascii)
        
        let sessionDelegate = NoRedirectURLSessionDelegate()
        let session = URLSession(configuration: .default, delegate: sessionDelegate, delegateQueue: nil)
        
        let (body, response) = try await session.data(for: urlRequest)
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                Log.debug(body)
            }
        }
    }
    
    private func markNotificationAsProcessed(notification: OpenEmailModel.Notification) async throws {
        var notification = notification
        notification.isProcessed = true
        try await notificationsStore.storeNotification(notification)
    }
    
    // MARK: Messages
    
    public func executeNotifications(localUser: LocalUser) async throws -> [String] {
        var syncedAddresses: [String] = []
        let notifications = await (try? notificationsStore.allNotifications()) ?? []
        try await withThrowingTaskGroup(of: Void.self) { notificationsTaskGroup in
            for notification in notifications {
                notificationsTaskGroup.addTask {
                    if notification.isExpired() {
                        // Maximum lifetime of a notification is 7 days.
                        try await self.notificationsStore.deleteNotification(id: notification.id)
                        return
                    }
                    if notification.isProcessed {
                        // we've already completed a fetch based on this notification,
                        // it can be ignored. A new notification may arrive of the same author.
                        return
                    }
                    
                    if let contact = try await self.contactsStore.contact(id: notification.link),
                       let contactAddress = EmailAddress(contact.address),
                       let contactProfile = try await self.fetchProfile(address: contactAddress) {
                        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                            taskGroup.addTask {
                                try await self.fetchRemoteMessages(localUser: localUser, authorProfile: contactProfile)
                            }
                            taskGroup.addTask {
                                try await self.fetchRemoteBroadcastMessages(localUser: localUser, authorProfile: contactProfile)
                            }
                            try await taskGroup.waitForAll()
                        }
                        try await self.markNotificationAsProcessed(notification: notification)
                        syncedAddresses.append(contactAddress.address)
                    }
                }
            }
            
            try await notificationsTaskGroup.waitForAll()
        }
        return syncedAddresses
    }
    
    public func fetchRemoteMessageIds(localUser: LocalUser, authorProfile: Profile) async throws -> [String] {
        let connectionLink = localUser.connectionLinkFor(remoteAddress: authorProfile.address.address)
        if let messageIds = try await withAllRespondingDelegatedHosts(address: authorProfile.address, handler: { hostname -> [String] in
            let authNonceList = try Nonce(localUser: localUser).sign(host: hostname)
            return try await self.fetchLinkMessageIdsFromAgent(
                agentHostname: hostname,
                authorProfile: authorProfile,
                link: connectionLink,
                nonce: authNonceList
            )
        }) {
            return messageIds.flatMap({ $0 })
        }
        return []
    }
    
    public func fetchLocalMessageIds(localUser: LocalUser, authorProfile: Profile) async throws -> [String] {
        if let messageIds = try await withAllRespondingDelegatedHosts(address: authorProfile.address, handler: { hostname -> [String] in
            let authNonceList = try Nonce(localUser: localUser).sign(host: hostname)
            return try await self.fetchLocalMessageIdsFromAgent(
                agentHostname: hostname,
                authorProfile: authorProfile,
                nonce: authNonceList
            )
        }) {
            return messageIds.flatMap({ $0 })
        }
        return []
    }
    
    public func fetchRemoteBroadcastMessageIds(localUser: LocalUser, authorProfile: Profile) async throws -> [String] {
        if let messageIds = try await withAllRespondingDelegatedHosts(address: authorProfile.address, handler: { hostname -> [String] in
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            return try await self.fetchBroadcastMessageIdsFromAgent(
                agentHostname: hostname,
                authorProfile: authorProfile,
                nonce: authNonce
            )
        }) {
            return messageIds.flatMap({ $0 })
        }
        return []
    }
    
    public func fetchLocalMessages(localUser: LocalUser, localProfile: Profile) async throws -> [String] {
        guard localUser.address.address == localProfile.address.address else {
            throw ClientError.invalidProfile
        }
        
        let messageIds = try await fetchLocalMessageIds(localUser: localUser, authorProfile: localProfile)
        try await withThrowingTaskGroup(of: Void.self) {group in
            for messageId in messageIds {
                group.addTask {
                    let existingMessage = try? await self.messagesStore.message(id: messageId)
                    if var message = existingMessage {
                        Log.info("local message \(messageId) already fetched, ignoring")
                        
                        // Is message broadcast or completely delivered?
                        if message.isBroadcast || message.deliveries.count == message.readers.count {
                            return
                        }
                        
                        Log.info("fetching message delivery information")
                        // Fetch deliveries for the message and update local db
                        if let deliveryInfo = try await self.fetchMessageDeliveryInformation(localUser: localUser, messageId: messageId) {
                            var deliveriesList: [String] = []
                            for (lnk, _) in deliveryInfo {
                                if let contact = try await self.contactsStore.contact(id: lnk) {
                                    deliveriesList.append(contact.address)
                                }
                            }
                            message.deliveries = deliveriesList
                            try await self.messagesStore.storeMessage(message)
                        }
                        
                        // Notify again all readers not in deliveries
                        let setReaders = Set(message.readers)
                        let setDeliveries = Set(message.deliveries)
                        let pendingDeliveriesAddresses = Array(setReaders.subtracting(setDeliveries))
                        var pendingDeliveriesEmailAddresses: [EmailAddress] = []
                        for address in pendingDeliveriesAddresses {
                            if let emailAddress = EmailAddress(address) {
                                pendingDeliveriesEmailAddresses.append(emailAddress)
                            }
                        }
                        try await self.notifyReaders(readersAddresses: pendingDeliveriesEmailAddresses, localUser: localUser)
                    }
                    
                    do {
                        try await self.withFirstRespondingDelegatedHost(address: localProfile.address, handler: { hostname in
                            Log.info("Fetching local message \(messageId)")
                            try await self.fetchLocalMessageFromAgent(host: hostname, localUser: localUser, authorProfile: localProfile, messageID: messageId)
                        })
                    } catch {
                        Log.error("Could not fetch message: \(error)")
                        return
                    }
                }
            }
            try await group.waitForAll()
        }
        
        return messageIds
    }
    
    public func fetchRemoteMessages(localUser: LocalUser, authorProfile: Profile) async throws {
        let messageIds = try await fetchRemoteMessageIds(localUser: localUser, authorProfile: authorProfile)
        let maxConcurrentTasks = min(5, messageIds.count)
        
        
        let connectionLink = localUser.connectionLinkFor(remoteAddress: authorProfile.address.address)
        
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            for index in 0..<maxConcurrentTasks {
                taskGroup.addTask {
                    try await self.processRemoteMessage(
                        messageId: messageIds[index],
                        authorProfile: authorProfile,
                        connectionLink: connectionLink,
                        localUser: localUser
                    )
                }
            }
            
            var tmpIndex = maxConcurrentTasks
            
            while try await taskGroup.next() != nil {
                if (tmpIndex < messageIds.count) {
                    let i = tmpIndex
                    tmpIndex += 1
                    taskGroup.addTask {
                        try await self.processRemoteMessage(
                            messageId: messageIds[i],
                            authorProfile: authorProfile,
                            connectionLink: connectionLink,
                            localUser: localUser
                        )
                    }
                }
            }
        }
    }
    
    private func processRemoteMessage(messageId: String, authorProfile: Profile, connectionLink: String, localUser: LocalUser) async throws {
        if try await messagesStore.message(id: messageId) != nil {
            Log.info("message \(messageId) from \(authorProfile.address.address) already fetched, ignoring")
            return
        }
        try await self.withFirstRespondingDelegatedHost(address: authorProfile.address, handler: { hostname in
            Log.info("Fetching messages from \(authorProfile.address.address)")
            try await self.fetchLinkMessageFromAgent(host: hostname, localUser: localUser, authorProfile: authorProfile, connectionLink: connectionLink, messageID: messageId)
        })
    }
    
    public func fetchRemoteBroadcastMessages(localUser: LocalUser, authorProfile: Profile) async throws {
        let messageIds = try await fetchRemoteBroadcastMessageIds(localUser: localUser, authorProfile: authorProfile)
        
        let maxConcurrentTasks = min(5, messageIds.count)
        
        func getRemoteMessage(_ messageId: String) async throws {
            if try await self.messagesStore.message(id: messageId) != nil {
                Log.info("message \(messageId) from \(authorProfile.address.address) already fetched, ignoring")
                return
            }
            try await self.withFirstRespondingDelegatedHost(address: authorProfile.address, handler: { hostname in
                Log.info("Fetching messages from \(authorProfile.address.address)")
                try await self.fetchBroadcastMessageFromAgent(host: hostname, localUser: localUser, authorProfile: authorProfile, messageID: messageId)
            })
        }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            
            for index in 0..<maxConcurrentTasks {
                group.addTask {
                    try await getRemoteMessage(messageIds[index])
                }
            }
            
            var tmpIndex = maxConcurrentTasks
            
            while try await group.next() != nil {
                if (tmpIndex < messageIds.count) {
                    let i = tmpIndex
                    tmpIndex += 1
                    group.addTask {
                        try await getRemoteMessage(messageIds[i])
                    }
                }
            }
        }
    }
    
    private func fetchBroadcastMessageIdsFromAgent(agentHostname: String, authorProfile: Profile, nonce: String) async throws -> [String] {
        guard let url = URL(string: "https://\(agentHostname)/mail/\(authorProfile.address.hostPart)/\(authorProfile.address.localPart)/messages") else {
            throw ClientError.invalidEndpoint
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        urlRequest.setValue(nonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            Log.error("Could not fetch message list. Unexpected response: \(response)")
            return []
        }
        
        guard httpResponse.statusCode == 200 /* OK */ else {
            // TODO: Authentication may have failed or other errors. Throw instead?
            Log.error("Could not fetch message list. status: \(httpResponse.statusCode)")
            return []
        }
        if let contentString = String(data: data, encoding: .utf8) {
            return contentString
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
    
    private func fetchLinkMessageIdsFromAgent(agentHostname: String, authorProfile: Profile, link: String, nonce: String) async throws -> [String] {
        guard let url = URL(string: "https://\(agentHostname)/mail/\(authorProfile.address.hostPart)/\(authorProfile.address.localPart)/link/\(link)/messages") else {
            throw ClientError.invalidEndpoint
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        urlRequest.setValue(nonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            Log.error("Could not fetch message list. Unexpected response: \(response)")
            return []
        }
        
        guard httpResponse.statusCode == 200 /* OK */ else {
            // TODO: Authentication may have failed or other errors. Throw instead?
            Log.error("Could not fetch message list. status: \(httpResponse.statusCode)")
            return []
        }
        if let contentString = String(data: data, encoding: .utf8) {
            return contentString
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
    
    private func fetchLocalMessageIdsFromAgent(agentHostname: String, authorProfile: Profile, nonce: String) async throws -> [String] {
        guard let url = URL(string: "https://\(agentHostname)/home/\(authorProfile.address.hostPart)/\(authorProfile.address.localPart)/messages") else {
            throw ClientError.invalidEndpoint
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        urlRequest.setValue(nonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            Log.error("Could not fetch message list. Unexpected response: \(response)")
            return []
        }
        
        guard httpResponse.statusCode == 200 /* OK */ else {
            // TODO: Authentication may have failed or other errors. Throw instead?
            Log.error("Could not fetch message list. status: \(httpResponse.statusCode)")
            return []
        }
        if let contentString = String(data: data, encoding: .utf8) {
            return contentString
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
    
    private func fetchLocalMessageFromAgent(host: String, localUser: LocalUser, authorProfile: Profile, messageID: String) async throws {
        guard let url = URL(string: "https://\(host)/home/\(authorProfile.address.hostPart)/\(authorProfile.address.localPart)/messages/\(messageID)") else {
            throw ClientError.invalidEndpoint
        }
        
        try await fetchMessageFromAgent(url: url, localUser: localUser, authorProfile: authorProfile, messageID: messageID, isBroadcastAllowed: true)
    }
    
    private func fetchLinkMessageFromAgent(host: String, localUser: LocalUser, authorProfile: Profile, connectionLink: String, messageID: String) async throws {
        guard let url = URL(string: "https://\(host)/mail/\(authorProfile.address.hostPart)/\(authorProfile.address.localPart)/link/\(connectionLink)/messages/\(messageID)") else {
            throw ClientError.invalidEndpoint
        }
        
        try await fetchMessageFromAgent(url: url, localUser: localUser, authorProfile: authorProfile, messageID: messageID, isBroadcastAllowed: false)
    }
    
    private func fetchBroadcastMessageFromAgent(host: String, localUser: LocalUser, authorProfile: Profile, messageID: String) async throws {
        guard let url = URL(string: "https://\(host)/mail/\(authorProfile.address.hostPart)/\(authorProfile.address.localPart)/messages/\(messageID)") else {
            throw ClientError.invalidEndpoint
        }
        
        try await fetchMessageFromAgent(url: url, localUser: localUser, authorProfile: authorProfile, messageID: messageID, isBroadcastAllowed: true)
    }
    
    private func fetchMessageFromAgent(
        url: URL,
        localUser: LocalUser,
        authorProfile: Profile,
        messageID: String,
        isBroadcastAllowed: Bool
    ) async throws {
        /// Make HEAD request. If it succeeds and the headers are authentic, proceed to
        /// GET the payload from the same host.
        
        let envelope = try await fetchEnvelope(for: url, messageID: messageID, localUser: localUser, authorProfile: authorProfile)
        guard let contentHeaders = envelope.contentHeaders else {
            throw ClientError.invalidContentHeaders
        }
        
        guard contentHeaders.parentId == nil else {
            // only process root messages
            return
        }
        
        let isBroadcast = envelope.isBroadcast()
        
        if !isBroadcastAllowed && isBroadcast {
            // Message cannot be broadcast
            throw ClientError.invalidContentHeaders
        }
        
        let readers: [String] =  isBroadcast ? [] : contentHeaders.readersAddresses?.map { $0.address } ?? []
        
        // For root messages store under <messageId>/payload and <messageId>/headers
        let envelopeFileName = ENVELOPE_FILENAME
        let headersFileName = CONTENT_HEADERS_FILENAME
        let payloadFileName = PAYLOAD_FILENAME
        let destinationMessageID = messageID
        
        // Save parts
        let envelopeFileURL = try makeMessageFileURL(localUser: localUser, messageID: destinationMessageID, fileName: envelopeFileName)
        try envelope.dumpToFile(to: envelopeFileURL)
        
        let headersFileURL = try makeMessageFileURL(localUser: localUser, messageID: destinationMessageID, fileName: headersFileName)
        try contentHeaders.dumpToFile(to: headersFileURL)
        
        let payloadFileURL = try makeMessageFileURL(localUser: localUser, messageID: destinationMessageID, fileName: payloadFileName)
        
        let downloader = Downloader()
        try await downloader.downloadFile(from: url, to: payloadFileURL, accessKey: envelope.accessKey, localUser: localUser)
        
        let isMessageFromSelf = authorProfile.address == localUser.address
        
        let payloadBody = try? String(contentsOf: payloadFileURL, encoding: .utf8)
        
        // Add the root message, or update stub
        if var rootMessage = try? await self.messagesStore.message(id: messageID) {
            rootMessage.size = contentHeaders.size
            rootMessage.body = payloadBody
            try await self.messagesStore.storeMessage(rootMessage)
        } else {
            let attachments = attachments(from: contentHeaders)
            
            let rootMessageStub = OpenEmailModel.Message(
                localUserAddress: localUser.address.address,
                id: destinationMessageID,
                size: contentHeaders.size,
                authoredOn: contentHeaders.date,
                receivedOn: .now,
                author: authorProfile.address.address,
                readers: readers,
                subject: contentHeaders.subject,
                body: payloadBody,
                subjectId: contentHeaders.subjectId,
                isBroadcast: isBroadcast,
                accessKey: envelope.accessKey,
                isRead: isMessageFromSelf,
                deletedAt: nil,
                attachments: attachments
            )
            try await self.messagesStore.storeMessage(rootMessageStub)
            
            downloadSmallAttachments(attachments)
        }
    }
    
    private func attachments(from contentHeaders: ContentHeaders) -> [Attachment] {
        (contentHeaders.files ?? []).map { fileInfo in
            Attachment(
                id: "\(contentHeaders.messageID)_\(fileInfo.name)",
                parentMessageId: contentHeaders.messageID,
                fileMessageIds: fileInfo.messageIds,
                filename: fileInfo.name,
                size: fileInfo.size,
                mimeType: fileInfo.mimeType
            )
        }
    }
    
    private func downloadSmallAttachments(_ attachments: [Attachment]) {
        let maxFileSizeInBytes = UserDefaults.standard.attachmentsDownloadThresholdInMegaByte.megabytesToBytes()
        
        let attachmentsManager = AttachmentsManager.shared
        
        for attachment in attachments {
            guard  attachment.size <= maxFileSizeInBytes else { continue }
            
            Log.debug("automatically downloading file: \(attachment.filename)")
            attachmentsManager.download(attachment: attachment)
        }
    }
    
    public func downloadFileAttachment(messageIds: [String], parentId: String, localUser: LocalUser, filename: String) async throws {
        try await self.withFirstRespondingDelegatedHost(address: localUser.address) { host in
            // get parent message
            guard let parentMessage = try await self.messagesStore.message(id: parentId) else {
                throw MessageError.invalidParentMessage
            }
            
            // get author profile
            guard
                let authorEmailAddress = EmailAddress(parentMessage.author),
                let authorProfile = try await self.fetchProfile(address: authorEmailAddress, force: false)
            else {
                throw MessageError.missingAuthor
            }
            
            let downloader = Downloader()
            
            var partUrls = [URL]()
            
            // download each part
            for (index, messageId) in messageIds.enumerated() {
                let url: URL?
                if localUser.address == authorEmailAddress {
                    url = URL(string: "https://\(host)/home/\(authorEmailAddress.hostPart)/\(authorEmailAddress.localPart)/messages/\(messageId)")
                } else {
                    let connectionLink = localUser.connectionLinkFor(remoteAddress: authorEmailAddress.address)
                    url = URL(string: "https://\(host)/mail/\(authorEmailAddress.hostPart)/\(authorEmailAddress.localPart)/link/\(connectionLink)/messages/\(messageId)")
                }
                
                guard let url else {
                    throw ClientError.invalidEndpoint
                }
                
                Log.debug("\(parentId) \(filename): downloading part \(index + 1)/\(messageIds.count)")
                
                // download envelope of partial message to get accessKey
                let envelope = try await self.fetchEnvelope(for: url, messageID: messageId, localUser: localUser, authorProfile: authorProfile)
                
                let partialFileURL = try self.makeMessageFileURL(localUser: localUser, messageID: parentMessage.id, fileName: "\(parentMessage.id)_\(index).part")
                partUrls.append(partialFileURL)
                
                // download actual payload
                try await downloader.downloadFile(from: url, to: partialFileURL, accessKey: envelope.accessKey, localUser: localUser)
            }
            
            let finalFileURL = try self.makeMessageFileURL(localUser: localUser, messageID: parentMessage.id, fileName: filename)
            try Utils.concatenateFiles(at: partUrls, to: finalFileURL)
            
            for partUrl in partUrls {
                try? FileManager.default.removeItem(at: partUrl)
            }
        }
    }
    
    /// Performs a HEAD request to the specified URL and retrieves response headers.
    /// - Parameters:
    ///   - url: The URL for the HEAD request.
    ///   - messageID: The message ID
    ///   - localUser: Local user
    ///   - authorProfile: Profile of the remote user whose message is being fetched
    func fetchEnvelope(for url: URL, messageID: String, localUser: LocalUser, authorProfile: Profile) async throws -> Envelope {
        let nonce = try Nonce(localUser: localUser).sign(host: url.host()!)
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue(nonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: ClientError.invalidHTTPResponse)
                    return
                }
                
                var envelope = Envelope(messageID: messageID, localUser: localUser, authorProfile: authorProfile)
                for (key, value) in httpResponse.allHeaderFields {
                    if let key = key as? String, let value = value as? String {
                        try? envelope.assignHeaderValue(key: key, value: value)
                    }
                }
                
                do {
                    try envelope.assertEnvelopeAuthenticity()
                    try envelope.openContentHeaders()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: envelope)
            }
            
            task.resume()
        }
    }
    
    private func messageFileURL(localUser: LocalUser, messageID: String, fileName: String) throws -> (URL, URL) {
        let messageFolder = FileManager.default.messageFolderURL(userAddress: localUser.address.address, messageID: messageID)
        return (messageFolder, messageFolder.appending(path: fileName))
    }
    
    private func makeMessageFileURL(localUser: LocalUser, messageID: String, fileName: String) throws -> URL {
        let (messageFolder, fileUrl) = try messageFileURL(localUser: localUser, messageID: messageID, fileName: fileName)
        try makeFolderIfNeeded(url: messageFolder)
        return fileUrl
    }
    
    private func makeFolderIfNeeded(url: URL) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.absoluteString) {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    public func uploadPrivateMessage(
        localUser: LocalUser,
        subject: String,
        readersAddresses: [EmailAddress],
        body: Data,
        urls: [URL],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String? {
        guard !readersAddresses.isEmpty else {
            throw ClientError.invalidReaders
        }
        
        let sendingDate = Date()
        let messageID = newMessageID(localUserAddress: localUser.address)
        var accessProfilesMap:[String:Profile] = [:]
        var accessLinkAddresses = readersAddresses
        accessLinkAddresses.append(localUser.address)
        
        for readerAddress in accessLinkAddresses {
            if accessProfilesMap[readerAddress.address] != nil {
                continue
            }
            guard let readerProfile = try await fetchProfile(address: readerAddress, force: false),
                  let _ = readerProfile[.encryptionKey],
                  let _ = readerProfile[.signingKey] else {
                // Not all readers can be accessed
                // TODO: Report which reader is problematic
                throw ClientError.inaccessibleReaders
            }
            accessProfilesMap[readerAddress.address] = readerProfile
        }
        
        if accessProfilesMap.isEmpty {
            throw MessageError.noValidReaders
        }
        
        if body.isEmpty && urls.isEmpty {
            throw MessageError.emptyMessage
        }
        
        // Only root message will get files info
        var allFileParts: [(MessageFilePartInfo)]? = nil
        
        var attachments = [Attachment]()
        
        if !urls.isEmpty {
            allFileParts = [(MessageFilePartInfo)]()
            for url in urls {
                var fileParts = [(MessageFilePartInfo)]()
                
                let urlInfo = try getURLInfo(url)
                if urlInfo.size <= MAX_MESSAGE_SIZE {
                    // File data fits into a single message
                    let (bytesChecksum, _) = try Crypto.fileChecksum(url: url)
                    let partMessageId = newMessageID(localUserAddress: localUser.address)
                    let messageFilePartInfo = MessageFilePartInfo(urlInfo: urlInfo, messageId: partMessageId, part: 1, size: urlInfo.size, checksum: bytesChecksum, totalParts: 1)
                    fileParts.append(messageFilePartInfo)
                } else {
                    // File is larger than MAX_MESSAGE_SIZE and must be split into multiple messages
                    var offset: UInt64 = 0
                    var partCount: UInt64 = 1
                    let (q, _) = urlInfo.size.quotientAndRemainder(dividingBy: MAX_MESSAGE_SIZE)
                    let totalParts = q + 1
                    
                    while offset < urlInfo.size {
                        let partMessageId = newMessageID(localUserAddress: localUser.address)
                        let bytesCount: UInt64 = min(urlInfo.size - offset, MAX_MESSAGE_SIZE)
                        let (bytesChecksum, _) = try Crypto.fileChecksum(url: url, fromOffset: offset, bytesCount: bytesCount)
                        let messageFilePartInfo = MessageFilePartInfo(urlInfo: urlInfo, messageId: partMessageId, part: partCount, size: bytesCount, checksum: bytesChecksum, offset: offset, totalParts: totalParts)
                        
                        fileParts.append(messageFilePartInfo)
                        
                        offset += bytesCount
                        partCount += 1
                    }
                }
                
                let filename = urlInfo.name
                let attachment = Attachment(
                    id: "\(messageID)_\(filename)",
                    parentMessageId: messageID,
                    fileMessageIds: fileParts.map { $0.messageId },
                    filename: filename,
                    size: urlInfo.size,
                    mimeType: urlInfo.mimeType
                )
                attachments.append(attachment)
                
                allFileParts?.append(contentsOf: fileParts)
            }
            
            if let allFileParts {
                for (index, fpart) in allFileParts.enumerated() {
                    guard !Task.isCancelled else { return nil }
                    
                    let fileContent = try ContentHeaders(
                        messageID: fpart.messageId,
                        date: sendingDate,
                        subject: subject,
                        subjectID: messageID,
                        parentID: messageID,
                        checksum: fpart.checksum!,
                        category: .personal,
                        size: fpart.size,
                        authorAddress: localUser.address,
                        readersAddresses: readersAddresses)
                    
                    Log.debug("uploading file part \(index + 1) of \(allFileParts.count)…")
                    
                    try await uploadPrivateFileMessage(content: fileContent, localUser: localUser, accessProfilesMap: accessProfilesMap, messageFilePartInfo: fpart)
                    
                    let progress = Double(index + 1) / Double(allFileParts.count)
                    progressHandler(progress)
                }
            }
        }
        
        let (bodyChecksum, _) = Crypto.checksum(data: body)
        
        let content = try ContentHeaders(
            messageID: messageID,
            date: sendingDate,
            subject: subject,
            subjectID: messageID,
            parentID: nil,
            fileParts: allFileParts,
            checksum: bodyChecksum,
            category: .personal,
            size: UInt64(body.count),
            authorAddress: localUser.address,
            readersAddresses: readersAddresses)
        
        // Now upload the root message. Only the root message may have a body.
        try await uploadPrivateRootMessage(plainBody: body, content: content, localUser: localUser, accessProfilesMap: accessProfilesMap, attachments: attachments)
        
        let notifyReaderAddresses = readersAddresses.filter{ $0.address != localUser.address.address }
        try await notifyReaders(readersAddresses: notifyReaderAddresses, localUser: localUser)
        
        return messageID
    }
    
    public func uploadBroadcastMessage(
        localUser: LocalUser,
        subject: String,
        body: Data,
        urls: [URL],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String? {
        let sendingDate = Date()
        let messageID = newMessageID(localUserAddress: localUser.address)
        
        if body.isEmpty && urls.isEmpty {
            throw MessageError.emptyMessage
        }
        
        // Only root message will get files info
        var allFileParts: [(MessageFilePartInfo)]? = nil
        
        var attachments = [Attachment]()
        
        if !urls.isEmpty {
            allFileParts = [(MessageFilePartInfo)]()
            for url in urls {
                var fileParts = [(MessageFilePartInfo)]()
                
                let urlInfo = try getURLInfo(url)
                if urlInfo.size <= MAX_MESSAGE_SIZE {
                    // File data fits into a single message
                    let (bytesChecksum, _) = try Crypto.fileChecksum(url: url)
                    let partMessageId = newMessageID(localUserAddress: localUser.address)
                    let messageFilePartInfo = MessageFilePartInfo(urlInfo: urlInfo, messageId: partMessageId, part: 1, size: urlInfo.size, checksum: bytesChecksum, totalParts: 1)
                    fileParts.append(messageFilePartInfo)
                } else {
                    // File is larger than MAX_MESSAGE_SIZE and must be split into multiple messages
                    var offset: UInt64 = 0
                    var partCount: UInt64 = 1
                    let (q, _) = urlInfo.size.quotientAndRemainder(dividingBy: MAX_MESSAGE_SIZE)
                    let totalParts = q + 1
                    
                    while offset < urlInfo.size {
                        let partMessageId = newMessageID(localUserAddress: localUser.address)
                        let bytesCount: UInt64 = min(urlInfo.size - offset, MAX_MESSAGE_SIZE)
                        let (bytesChecksum, _) = try Crypto.fileChecksum(url: url, fromOffset: offset, bytesCount: bytesCount)
                        let messageFilePartInfo = MessageFilePartInfo(urlInfo: urlInfo, messageId: partMessageId, part: partCount, size: bytesCount, checksum: bytesChecksum, offset: offset, totalParts: totalParts)
                        
                        fileParts.append(messageFilePartInfo)
                        
                        offset += bytesCount
                        partCount += 1
                    }
                }
                
                // move file to message folder
                let filename = url.lastPathComponent
                let attachment = Attachment(
                    id: "\(messageID)_\(filename)",
                    parentMessageId: messageID,
                    fileMessageIds: fileParts.map { $0.messageId },
                    filename: filename,
                    size: urlInfo.size,
                    mimeType: urlInfo.mimeType
                )
                attachments.append(attachment)
                
                allFileParts?.append(contentsOf: fileParts)
            }
            
            if let allFileParts {
                for (index, fpart) in allFileParts.enumerated() {
                    guard !Task.isCancelled else { return nil }
                    
                    let fileContent = try ContentHeaders(
                        messageID: fpart.messageId,
                        date: sendingDate,
                        subject: subject,
                        subjectID: messageID,
                        parentID: messageID,
                        checksum: fpart.checksum!,
                        category: .personal,
                        size: fpart.size,
                        authorAddress: localUser.address)
                    
                    Log.debug("uploading file part \(index + 1) of \(allFileParts.count)…")
                    
                    try await uploadBroadcastFileMessage(content: fileContent, localUser: localUser, messageFilePartInfo: fpart)
                    
                    let progress = Double(index + 1) / Double(allFileParts.count)
                    progressHandler(progress)
                }
            }
        }
        
        let (bodyChecksum, _) = Crypto.checksum(data: body)
        
        let content = try ContentHeaders(
            messageID: messageID,
            date: sendingDate,
            subject: subject,
            subjectID: messageID,
            parentID: nil,
            fileParts: allFileParts,
            checksum: bodyChecksum,
            category: .personal,
            size: UInt64(body.count),
            authorAddress: localUser.address)
        
        // Now upload the root message. Only the root message may have a body.
        try await uploadBroadcastRootMessage(plainBody: body, content: content, localUser: localUser, attachments: attachments)
        
        return messageID
    }
    
    public func notifyReaders(readersAddresses: [EmailAddress], localUser: LocalUser) async throws {
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            for readerAddress in readersAddresses {
                // Ensure we are not notifying local users
                if localUser.address.address == readerAddress.address {
                    continue
                }
                taskGroup.addTask {
                    try await self.notifyAddress(localUser: localUser, remoteAddress: readerAddress)
                    Log.info("notified \(readerAddress.address)")
                }
            }
            try await taskGroup.waitForAll()
        }
    }
    
    private func uploadPrivateFileMessage(content: ContentHeaders, localUser: LocalUser, accessProfilesMap: [String:Profile], messageFilePartInfo: MessageFilePartInfo) async throws {
        guard let url = messageFilePartInfo.urlInfo.url else {
            throw ClientError.invalidFileURL
        }
        var envelope = Envelope(localUser: localUser, contentHeaders: content)
        let accessKey = try Crypto.generateRandomBytes(length: 32)
        
        try envelope.embedPrivateContentHeaders(accessKey: accessKey, accessProfilesMap: accessProfilesMap)
        try envelope.seal(payloadSeal: PayloadSeal(algorithm: Crypto.SYMMETRIC_CIPHER))
        
        let (_,sealedBody) = try Crypto.encryptFilePart_xchacha20poly1305(inputURL: url, secretkey: accessKey, bytesCount: messageFilePartInfo.size, offset: messageFilePartInfo.offset)
        
        let uploader = Uploader(localUser: localUser)
        var oneSucceeded = false
        
        _ = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                let fixedEnvelope = envelope
                taskGroup.addTask {
                    try await uploader.uploadMessageToAgent(
                        agentHostname: hostname,
                        envelope: fixedEnvelope,
                        uploadData: sealedBody
                    )
                }
                
                for try await _ in taskGroup {
                    oneSucceeded = true
                }
                if !oneSucceeded {
                    throw ClientError.uploadFailure
                }
                Log.info("uploaded file message to all hosts \(url)")
            }
        })
    }
    
    
    private func uploadBroadcastFileMessage(content: ContentHeaders, localUser: LocalUser, messageFilePartInfo: MessageFilePartInfo) async throws {
        guard let url = messageFilePartInfo.urlInfo.url else {
            throw ClientError.invalidFileURL
        }
        var envelope = Envelope(localUser: localUser, contentHeaders: content)
        
        try envelope.embedBroadcastContentHeaders()
        try envelope.seal(payloadSeal: nil)
        
        let plainBody = try Crypto.readFilePart(inputURL: url, bytesCount: messageFilePartInfo.size, offset: messageFilePartInfo.offset)
        
        let uploader = Uploader(localUser: localUser)
        var oneSucceeded = false
        
        _ = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                let fixedEnvelope = envelope
                taskGroup.addTask {
                    try await uploader.uploadMessageToAgent(
                        agentHostname: hostname,
                        envelope: fixedEnvelope,
                        uploadData: [UInt8](plainBody)
                    )
                }
                
                for try await _ in taskGroup {
                    oneSucceeded = true
                }
                if !oneSucceeded {
                    throw ClientError.uploadFailure
                }
                Log.info("uploaded file message to all hosts \(url)")
            }
        })
    }
    
    
    
    private func getURLInfo(_ url: URL) throws -> URLInfo {
        guard let fileSize = FileManager.default.sizeOfFile(at: url) else {
            throw LocalError.fileAccessError
        }
        
        let fileType = url.mimeType()
        let encodedFilename = Utils.encodeHeaderValue(url.lastPathComponent)!
        var fileLastModificationTime = Date()
        if let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
           let lastModificationDate = resourceValues.contentModificationDate {
            fileLastModificationTime = lastModificationDate
        }
        
        return URLInfo(url: url, name: encodedFilename, mimeType: fileType, size: fileSize, modifedAt: fileLastModificationTime)
    }
    
    
    func newMessageID(localUserAddress: EmailAddress) -> String {
        let random = Crypto.generateRandomString(length: 24)
        let rawId = "\(random)\(localUserAddress.hostPart)\(localUserAddress.localPart)"
        let (sumStr, _) = Crypto.sha256sum(Data(rawId.bytes))
        return sumStr
    }
    
    
    private func uploadPrivateRootMessage(plainBody: Data, content: ContentHeaders, localUser: LocalUser, accessProfilesMap: [String:Profile], attachments: [Attachment]) async throws {
        var envelope = Envelope(localUser: localUser, contentHeaders: content)
        let accessKey = try Crypto.generateRandomBytes(length: 32)
        try envelope.embedPrivateContentHeaders(accessKey: accessKey, accessProfilesMap: accessProfilesMap)
        try envelope.seal(payloadSeal: PayloadSeal(algorithm: Crypto.SYMMETRIC_CIPHER))
        let sealedBody = try Crypto.encrypt_xchacha20poly1305(plainText: Array(plainBody), secretKey: accessKey)
        let uploader = Uploader(localUser: localUser)
        var oneSucceeded = false
        
        _ = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                let fixedEnvelope = envelope
                taskGroup.addTask {
                    try await uploader.uploadMessageToAgent(
                        agentHostname: hostname,
                        envelope: fixedEnvelope,
                        uploadData: sealedBody
                    )
                }
                
                for try await _ in taskGroup {
                    oneSucceeded = true
                }
                if !oneSucceeded {
                    throw ClientError.uploadFailure
                }
                Log.info("uploaded all message root bodies")
                try await self.storeOutgoingMessage(localUser: localUser, content: content, data: plainBody, attachments: attachments)
            }
        })
    }
    
    private func uploadBroadcastRootMessage(plainBody: Data, content: ContentHeaders, localUser: LocalUser, attachments: [Attachment]) async throws {
        var envelope = Envelope(localUser: localUser, contentHeaders: content)
        try envelope.embedBroadcastContentHeaders()
        try envelope.seal(payloadSeal: PayloadSeal(algorithm: Crypto.SYMMETRIC_CIPHER))
        
        let uploader = Uploader(localUser: localUser)
        var oneSucceeded = false
        
        _ = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                let fixedEnvelope = envelope
                taskGroup.addTask {
                    try await uploader.uploadMessageToAgent(
                        agentHostname: hostname,
                        envelope: fixedEnvelope,
                        uploadData: Array(plainBody)
                    )
                }
                
                for try await _ in taskGroup {
                    oneSucceeded = true
                }
                if !oneSucceeded {
                    throw ClientError.uploadFailure
                }
                Log.info("uploaded all message root bodies")
                try await self.storeOutgoingMessage(localUser: localUser, content: content, data: plainBody, attachments: attachments)
            }
        })
    }
    
    
    private func dumpPayload(to: URL, payload: Data) throws {
        FileManager.default.createFile(atPath: to.path, contents: nil, attributes: nil)
        let fileHandle = try FileHandle(forWritingTo: to)
        try fileHandle.write(contentsOf: payload)
        try fileHandle.close()
    }
    
    private func storeOutgoingMessage(localUser: LocalUser, content: ContentHeaders, data: Data, attachments: [Attachment]) async throws {
        if (try await messagesStore.message(id: content.messageID)) != nil {
            Log.info("outgoing message already present locally, not updating")
            return
        }
        
        guard content.parentId == nil else {
            // only store root messages
            return
        }
        
        var readers: [String] = []
        if let addresses = content.readersAddresses {
            readers = addresses.map { $0.address }
        }
        
        let headersFileName = CONTENT_HEADERS_FILENAME
        let payloadFileName = PAYLOAD_FILENAME
        
        let body = String(data: data, encoding: .utf8)
        
        try await self.messagesStore.storeMessage(
            OpenEmailModel.Message(
                localUserAddress: localUser.address.address,
                id: content.messageID,
                size: content.size,
                authoredOn: content.date,
                receivedOn: .now,
                author: localUser.address.address,
                readers: readers,
                subject: content.subject,
                body: body,
                subjectId: content.subjectId,
                isBroadcast: content.readersAddresses.isNilOrEmpty,
                accessKey: nil,
                isRead: true,
                deletedAt: nil,
                attachments: attachments
            )
        )
        
        let headersFileURL = try makeMessageFileURL(localUser: localUser, messageID: content.messageID, fileName: headersFileName)
        try content.dumpToFile(to: headersFileURL)
        
        let payloadFileURL = try makeMessageFileURL(localUser: localUser, messageID: content.messageID, fileName: payloadFileName)
        try dumpPayload(to: payloadFileURL, payload: data)
    }
    
    
    public func recallAuthoredMessage(localUser: LocalUser, messageId: String) async throws {
        if let responses = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            guard let url = URL(string: "https://\(hostname)/home/\(localUser.address.hostPart)/\(localUser.address.localPart)/messages/\(messageId)") else {
                throw ClientError.invalidEndpoint
            }
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
            urlRequest.httpMethod = "DELETE"
            
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        })
        {
            // All responses must be true
            if !responses.reduce(true, { $0 && $1 }) {
                throw ClientError.requestFailed
            }
        }
    }
    
    
    public func fetchMessageDeliveryInformation(localUser: LocalUser, messageId: String) async throws -> [(String, Date)]? {
        return try await withFirstRespondingDelegatedHost(address: localUser.address, handler: { hostname -> [(String, Date)]? in
            guard let url = URL(string: "https://\(hostname)/home/\(localUser.address.hostPart)/\(localUser.address.localPart)/messages/\(messageId)/deliveries") else {
                throw ClientError.invalidLink
            }
            
            var urlRequest = URLRequest(url: url)
            urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            urlRequest.setValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            guard let deliveryContent = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            var result: [(String, Date)] = []
            let deliveryLinks = deliveryContent.split(separator: "\n")
            for link in deliveryLinks {
                let parts = link.split(separator: ",", maxSplits: 2)
                if parts.count == 2 {
                    let linkStr = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let dateStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    var parsedDate: Date = .distantPast
                    if let unixTimestamp = TimeInterval(dateStr) {
                        parsedDate = Date(timeIntervalSince1970: unixTimestamp)
                    }
                    
                    result.append((linkStr, parsedDate))
                }
            }
            
            return result
        })
    }
    
    
    // MARK: Profiles
    
    public func fetchProfile(address: EmailAddress, force: Bool = false) async throws -> Profile? {
        if !force, let cachedProfile = profileCache.profile(for: address) {
            return cachedProfile
        }
        
        do {
            return try await withFirstRespondingDelegatedHost(address: address) { hostname -> Profile? in
                if let profileMap = try await self.fetchProfileDataFromHost(hostname: hostname, address: address) {
                    let profile = Profile(address: address, profileData: profileMap)
                    self.profileCache.setProfile(profile)
                    await self.updateLocalContact(profile: profile)
                    return profile
                }
                return nil
            }
        } catch {
            let nsError = error as NSError
            if nsError.code == -1200 {
                // this happens when the host doesn't support Mail V2
                throw UserError.emailV2notSupported
            }
            
            throw error
        }
    }
    
    private func fetchProfileDataFromHost(hostname: String, address: EmailAddress) async throws -> [ProfileAttribute: String]? {
        guard let url = URL(string: "https://\(hostname)/mail/\(address.hostPart)/\(address.localPart)/profile") else {
            throw UserError.invalidProfileURL
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .useProtocolCachePolicy
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UserError.profileReadError
        }
        
        let statusCode = httpResponse.statusCode
        
        if statusCode  == 404 {
            throw UserError.profileNotFound
        }
        
        guard statusCode == 200 else {
            throw UserError.profileReadError
        }
        
        guard let profileContent = String(data: data, encoding: .utf8) else {
            throw UserError.invalidProfile
        }
        return parseProfileContent(data: profileContent)
    }
    
    
    private func parseProfileContent(data: String) -> [ProfileAttribute: String] {
        var result = [ProfileAttribute: String]()
        let lines = data.split(separator: "\n")
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            if let separatorIndex = trimmedLine.firstIndex(of: ":") {
                let key = String(trimmedLine[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmedLine[trimmedLine.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespaces)
                
                if let pk = ProfileAttribute(rawValue: key) {
                    result[pk] = value
                }
            }
        }
        
        return result
    }
    
    private func updateLocalContact(profile: Profile) async {
        guard let contact = try? await contactsStore.contact(address: profile.address.address) else {
            return
        }
        
        let updatedContact = Contact(
            id: contact.id,
            addedOn: contact.addedOn,
            address: contact.address,
            receiveBroadcasts: contact.receiveBroadcasts,
            cachedName: profile[.name],
            cachedProfileImageURL: contact.cachedProfileImageURL
        )
        try? await contactsStore.storeContact(updatedContact)
    }
    
    private func upsertLocalContact(localUser: LocalUser, address: EmailAddress) async throws {
        if localUser.address.address == address.address {
            // Do not store own address in contacts
            return
        }
        
        let id = localUser.connectionLinkFor(remoteAddress: address.address)
        
        let contact: Contact
        if let existingContact = try? await contactsStore.contact(address: address.address) {
            contact = existingContact
        } else {
            contact = Contact(id: id, addedOn: Date(), address: address.address, receiveBroadcasts: true)
        }
        try await contactsStore.storeContact(contact)
    }
    
    public func fetchProfileImage(address: EmailAddress, force: Bool) async throws -> Data? {
        return try await withFirstRespondingDelegatedHost(address: address) { hostname -> Data? in
            guard let url = URL(string: "https://\(hostname)/mail/\(address.hostPart)/\(address.localPart)/image") else {
                return nil
            }
            
            if !force {
                if let cachedData = self.profileImageCache.imageData(for: url) {
                    return cachedData
                }
            }
            
            // don't fetch image if it was fetched recently
            let lastFetchDate = self.imageRequestTimestamps[url] ?? .distantPast
            if lastFetchDate.addingTimeInterval(Self.imageRequestCooldown) > .now {
                return nil
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                self.imageRequestTimestamps[url] = Date()
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200  {
                        self.profileImageCache.setImageData(data, for: url)
                        return data
                    }
                }
            } catch {
                //
            }
            return nil
        }
    }
    
    private func profileImageUrl(localUser: LocalUser, hostname: String) -> URL? {
        URL(string: "https://\(hostname)/home/\(localUser.address.hostPart)/\(localUser.address.localPart)/image")
    }
    
    public func uploadProfileImage(localUser: LocalUser, imageData: Data) async throws {
        _ = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            guard let url = self.profileImageUrl(localUser: localUser, hostname: hostname) else {
                throw ClientError.invalidEndpoint
            }
            
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
            urlRequest.httpMethod = "PUT"
            
            urlRequest.httpBody = imageData
            
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200  {
                    throw ClientError.uploadFailure
                } else {
                    if let url = URL(string: "https://\(hostname)/mail/\(localUser.address.hostPart)/\(localUser.address.localPart)/image") {
                        self.profileImageCache.setImageData(imageData, for: url)
                        NotificationCenter.default.post(name: .profileImageUpdated, object: nil)
                    }
                }
            }
        })
    }
    
    public func deleteProfileImage(localUser: LocalUser) async throws {
        _ = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            guard let url = self.profileImageUrl(localUser: localUser, hostname: hostname) else {
                throw ClientError.invalidEndpoint
            }
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
            urlRequest.httpMethod = "DELETE"
            
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200  {
                    throw ClientError.requestFailed
                } else {
                    // update local image cache
                    if let url = URL(string: "https://\(hostname)/mail/\(localUser.address.hostPart)/\(localUser.address.localPart)/image") {
                        self.profileImageCache.removeImageData(for: url)
                        NotificationCenter.default.post(name: .profileImageUpdated, object: nil)
                    }
                }
            }
        })
    }
    
    public func uploadProfile(localUser: LocalUser, profile: Profile) async throws {
        guard profile[.signingKey] != nil else {
            throw ClientError.invalidProfile
        }
        
        _ = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            guard let url = URL(string: "https://\(hostname)/home/\(localUser.address.hostPart)/\(localUser.address.localPart)/profile") else {
                throw ClientError.invalidEndpoint
            }
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
            urlRequest.httpMethod = "PUT"
            
            guard let profileData = profile.serialize() else {
                throw ClientError.invalidProfile
            }
            urlRequest.httpBody = profileData
            
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200  {
                    throw ClientError.uploadFailure
                }
            }
        })
    }
    
    public func isAddressInContacts(localUser: LocalUser, address: EmailAddress) async throws -> Bool {
        if localUser.address.address == address.address {
            return true
        }
        let link = localUser.connectionLinkFor(remoteAddress: address.address)
        if let response = try await withFirstRespondingDelegatedHost(address: address, handler: { hostname -> Bool in
            guard let url = URL(string: "https://\(hostname)/mail/\(address.hostPart)/\(address.localPart)/link/\(link)") else {
                throw ClientError.invalidLink
            }
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            return true
        }) {
            return response
        }
        return false
    }
    
    public func updateBroadcastsForContact(localUser: LocalUser, address: EmailAddress, allowBroadcasts: Bool) async throws {
        let linkAddr = localUser.connectionLinkFor(
            remoteAddress: address.address
        )
        
        _ = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            guard let url = URL(string: "https://\(hostname)/home/\(localUser.address.hostPart)/\(localUser.address.localPart)/links/\(linkAddr)") else {
                throw ClientError.invalidEndpoint
            }
            
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            var urlRequest = URLRequest(url: url)
            
            let body = [
                "address=\(address.address)",
                "broadcasts=\(allowBroadcasts ? "Yes" : "No")"
            ].joined(separator: ";")
            
            let encryptedBody = try Crypto.encryptAnonymous(data: body.bytes, publicKey: localUser.publicEncryptionKey)
            let encodedBody = Crypto.base64encode(encryptedBody)
            
            urlRequest.setValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
            urlRequest.httpMethod = "PUT"
            urlRequest.httpBody = encodedBody.data(using: .ascii)
            
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200  {
                    throw ClientError.requestFailed
                }
            }
        })
    }
    
    public func getLinks(localUser: LocalUser) async throws -> [Link]? {
        return try await withFirstRespondingDelegatedHost(address: localUser.address) { hostname -> [Link]? in
            guard let url = URL(string: "https://\(hostname)/home/\(localUser.address.hostPart)/\(localUser.address.localPart)/links") else {
                throw ClientError.invalidEndpoint
            }
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            var urlRequest = URLRequest(url: url)
            urlRequest.setValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
            urlRequest.httpMethod = "GET"
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw ClientError.invalidHTTPResponse
            }
            
            guard let responseString = String(data: data, encoding: .utf8) else {
                throw ClientError.invalidHTTPResponse
            }
            
            let deliveryLinks = responseString.split(separator: "\n")
            var rv = [Link]()
            
            for link in deliveryLinks {
                do {
                    rv.append(try Link(encryptedLink: String(link), localUser: localUser))
                } catch ParsingError.badLinkAttributesStructure {
                    continue
                }
            }
            return rv
        }
    }
    
    public func storeContact(localUser: LocalUser, address: EmailAddress) async throws {
        guard localUser.address.address != address.address else {
            // Do not store own address in contacts
            return
        }
        let linkAddr = localUser.connectionLinkFor(remoteAddress: address.address)
        _ = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            guard let url = URL(string: "https://\(hostname)/home/\(localUser.address.hostPart)/\(localUser.address.localPart)/links/\(linkAddr)") else {
                throw ClientError.invalidEndpoint
            }
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            var urlRequest = URLRequest(url: url)
            
            let encryptedRemoteAddress = try Crypto.encryptAnonymous(data: address.address.bytes, publicKey: localUser.publicEncryptionKey)
            let encodedEncryptedAddress = Crypto.base64encode(encryptedRemoteAddress)
            
            urlRequest.setValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
            urlRequest.httpMethod = "PUT"
            urlRequest.httpBody = encodedEncryptedAddress.data(using: .ascii)
            
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200  {
                    throw ClientError.requestFailed
                }
            }
        })
    }
    
    public func syncContacts(localUser: LocalUser) async throws {
        // Fetch remote to local
        let allContacts = try await fetchContacts(localUser: localUser)
        for contact in allContacts {
            if let emailAddress = EmailAddress(contact.address) {
                try await upsertLocalContact(localUser: localUser, address: emailAddress)
            }
        }
        // Now store local to remote
        let allLocalContacts = try await contactsStore.allContacts()
        for contact in allLocalContacts {
            if let emailAddress = EmailAddress(contact.address) {
                try await storeContact(localUser: localUser, address: emailAddress)
            }
        }
    }
    
    public func deleteContact(localUser: LocalUser, address: EmailAddress) async throws {
        let linkAddr = localUser.connectionLinkFor(remoteAddress: address.address)
        _ = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            guard let url = URL(string: "https://\(hostname)/home/\(localUser.address.hostPart)/\(localUser.address.localPart)/links/\(linkAddr)") else {
                throw ClientError.invalidEndpoint
            }
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            var urlRequest = URLRequest(url: url)
            
            urlRequest.setValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
            urlRequest.httpMethod = "DELETE"
            
            let (_, response) = try await URLSession.shared.data(for: urlRequest)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200  {
                    throw ClientError.requestFailed
                }
            }
        })
    }
    
    
    public func fetchContacts(localUser: LocalUser) async throws -> [EmailAddress] {
        var allContacts: [EmailAddress] = []
        _  = try await withAllRespondingDelegatedHosts(address: localUser.address, handler: { hostname in
            guard let url = URL(string: "https://\(hostname)/home/\(localUser.address.hostPart)/\(localUser.address.localPart)/links") else {
                throw ClientError.invalidEndpoint
            }
            let authNonce = try Nonce(localUser: localUser).sign(host: hostname)
            var urlRequest = URLRequest(url: url)
            
            urlRequest.setValue(authNonce, forHTTPHeaderField: AUTHORIZATION_HEADER)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200  {
                    throw ClientError.requestFailed
                }
                if let contentString = String(data: data, encoding: .utf8) {
                    let lines = contentString.components(separatedBy: CharacterSet.newlines)
                    let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .unique()
                    for line in trimmedLines {
                        let parts = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        if parts.count == 2 {
                            let decryptedAddressBytes = try Crypto.decryptAnonymous(cipherText: parts[1], privateKey: localUser.privateEncryptionKey, publicKey: localUser.publicEncryptionKey)
                            if let decryptedAddress = String(bytes: decryptedAddressBytes, encoding: .ascii),
                               let decryptedEmailAddress = EmailAddress(decryptedAddress) {
                                allContacts.append(decryptedEmailAddress)
                            }
                        }
                    }
                }
            }
        })
        return allContacts
    }
    
}


private class NoRedirectURLSessionDelegate: NSObject, URLSessionTaskDelegate {
    var redirectLocation: URL?
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if let locationHeader = response.allHeaderFields["Location"] as? String, let locationURL = URL(string: locationHeader) {
            redirectLocation = locationURL
        }
        completionHandler(nil)
    }
}

import Foundation

public struct Notification: Identifiable {
    // The identification comes from the mail agent, and it represents
    // a unique identifier within user (reader) scope.
    public let id: String

    // Keeping track of the age of notification. Older than 7 days are
    // automatically purged.
    public let receivedOn: Date

    // The link to which the author is notifying. It should match the
    // email address.
    public let link: String

    // The address is untrusted until signature is verified.
    public var address: String?

    // Was the fetch based on the notification executed? This
    // indicator lets us determine when there are new messages from
    // the same author.
    public var isProcessed: Bool = false

    public var authorFingerPrint: String

    public init(id: String, receivedOn: Date, link: String, address: String? = nil, authorFingerPrint: String, isProccessed: Bool = false) {
        self.id = id
        self.receivedOn = receivedOn
        self.link = link
        self.address = address
        self.authorFingerPrint = authorFingerPrint
        self.isProcessed = isProccessed
    }

    public func isExpired() -> Bool {
        let calendar = Calendar.current
        if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) {
            return receivedOn < sevenDaysAgo
        }
        return false
    }
}

import Foundation
import SwiftData

public struct Contact: Identifiable, Equatable {
    public let id: String
    public let addedOn: Date
    public let address: String
    public let cachedName: String?
    public let cachedProfileImageURL: URL?
    public var receiveBroadcasts: Bool

    public init(id: String, addedOn: Date, address: String, receiveBroadcasts: Bool = true, cachedName: String? = nil, cachedProfileImageURL: URL? = nil) {
        self.id = id
        self.addedOn = addedOn
        self.address = address
        self.receiveBroadcasts = receiveBroadcasts
        self.cachedName = cachedName
        self.cachedProfileImageURL = cachedProfileImageURL
    }
}

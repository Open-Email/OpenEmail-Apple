import Foundation

public struct EmailAddress: Comparable, Codable, Identifiable, Hashable, Equatable {
    public let address: String
    public let hostPart: String
    public let localPart: String

    public static func isValid(_ value: String) -> Bool {
        guard !value.isEmpty else {
            return false
        }

        guard let emailRegex = try? Regex("^[a-z0-9][a-z0-9\\.\\-_\\+]{2,}@[a-z0-9.-]+\\.[a-z]{2,}|xn--[a-z0-9]{2,}$").ignoresCase() else {
            fatalError("invalid regular expression")
        }

        return value.wholeMatch(of: emailRegex) != nil
    }

    public var id: String { address }

    public init?(_ address: String?) {
        guard let address else {
            return nil
        }
        guard EmailAddress.isValid(address) else {
            return nil
        }
        
        let userParts = address.lowercased().components(separatedBy: "@")

        guard userParts.count == 2 else {
            return nil
        }

        self.localPart = userParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        self.hostPart = userParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        self.address = address.lowercased()
    }

    public static func < (lhs: EmailAddress, rhs: EmailAddress) -> Bool {
        lhs.address < rhs.address
    }

    public static func == (lhs: EmailAddress, rhs: EmailAddress) -> Bool {
        lhs.address == rhs.address
    }
}

import Foundation

public extension TimeInterval {
    static let MINUTE = 60.0
    static let HOUR = 60.0 * MINUTE
    static let DAY = 24.0 * HOUR

    static func days(_ amount: Int) -> TimeInterval {
        TimeInterval(DAY * Double(amount))
    }

    static func hours(_ amount: Int) -> TimeInterval {
        TimeInterval(HOUR * Double(amount))
    }
    
    static func minutes(_ amount: Int) -> TimeInterval {
        TimeInterval(MINUTE * Double(amount))
    }

    var asMinutes: Double { self / Self.MINUTE }
    var asHours: Double { self / Self.HOUR }
    var asDays: Double { self / Self.DAY }
}

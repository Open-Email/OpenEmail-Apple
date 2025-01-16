import Foundation

public extension Date {
    private static let calendar = Calendar.current

    private static func components(fromDate: Date) -> DateComponents {
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fromDate)
    }

    var components: DateComponents { Date.components(fromDate: self) }

    static func make(day: Int, month: Int, year: Int, hours: Int = 0, minutes: Int = 0) -> Date {
        let components = dateComponents(day: day, month: month, year: year, hours: hours, minutes: minutes)
        return calendar.date(from: components)!
    }
    
    static func makeToday(hours: Int = 0, minutes: Int = 0) -> Date {
        var components = calendar.dateComponents([.day, .month, .year], from: Date())
        components.hour = hours
        components.minute = minutes
        return calendar.date(from: components)!
    }

    static func dateComponents(day: Int, month: Int, year: Int, hours: Int = 0, minutes: Int = 0) -> DateComponents {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hours
        components.minute = minutes
        return components
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    func isOnSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    var isInFuture: Bool {
        self > Date()
    }

    var isInPast: Bool {
        self < Date()
    }

    var isInChristmasPeriod: Bool {
        let calendar = Date.calendar
        guard
            let christmasEve = calendar.date(from: DateComponents(year: calendar.component(.year, from: self), month: 12, day: 24)),
            let boxingDay = calendar.date(from: DateComponents(year: calendar.component(.year, from: self), month: 12, day: 26))
        else {
            return false
        }
        return self >= christmasEve && self <= boxingDay
    }

    func isTomorrow(relativeTo other: Date = Date()) -> Bool {
        let components = Date.calendar.dateComponents([.day, .month, .year], from: self)
        let todayComponents = Date.calendar.dateComponents([.day, .month, .year], from: other.addingDays(1))
        return components == todayComponents
    }

    func addingMinutes(_ minutes: Int) -> Date {
        var components = DateComponents()
        components.minute = minutes
        return Date.calendar.date(byAdding: components, to: self)!
    }

    func addingDays(_ days: Int) -> Date {
        var components = DateComponents()
        components.day = days
        return Date.calendar.date(byAdding: components, to: self)!
    }

    var beginningOfDay: Date {
        let dateComponents = Date.calendar.dateComponents([.year, .month, .day], from: self)
        return Date.calendar.date(from: dateComponents)!
    }

    var removingSeconds: Date {
        var components = self.components
        components.second = 0
        return Date.calendar.date(from: components)!
    }

    var endOfDay: Date {
        var components = self.components
        components.hour = 23
        components.minute = 59
        components.second = 59
        return Date.calendar.date(from: components)!
    }

    var nextFullHour: Date {
        var components = self.components
        components.hour! += 1
        components.minute = 0
        components.second = 0
        return Date.calendar.date(from: components)!
    }

    func formattedRelativeTime(relativeTo other: Date = Date()) -> String {
        RelativeDateTimeFormatter.default.localizedString(for: self, relativeTo: other)
    }
}

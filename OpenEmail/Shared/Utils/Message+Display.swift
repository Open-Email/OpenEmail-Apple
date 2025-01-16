import Foundation
import OpenEmailModel

extension Message {
    var formattedAuthoredOnDate: String {
        if authoredOn.isToday {
            return DateFormatter.timeOnly.string(from: authoredOn)
        } else if authoredOn.isYesterday {
            return "Yesterday"
        } else {
            return DateFormatter.shortDateOnly.string(from: authoredOn)
        }
    }

    var displayedSubject: String {
        var subject = subject.cleaned
        if subject.isEmpty {
            subject = "(no subject)"
        }
        return subject
    }
}

import Foundation

public func encodeHeaderValue(_ value: String) -> String? {
    var allowedCharacterSet = CharacterSet.urlHostAllowed
    allowedCharacterSet.remove(charactersIn: "=,;")

    return value.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)
}

public func decodeHeaderValue(_ value: String) -> String? {
    return value.removingPercentEncoding
}

/// Parses an ISO8601 date string and returns a valid Date object
public func parseISO8601Date(_ isoString: String) -> Date? {
    let cleanedString = cleanISO8601String(isoString)
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: "UTC")
    return dateFormatter.date(from: cleanedString)
}

/// Cleans an ISO8601 string by removing fractional seconds and fixing timezone format
private func cleanISO8601String(_ isoString: String) -> String {
    // Remove fractional seconds if present
    var cleanString = isoString
    if let dotIndex = cleanString.firstIndex(of: ".") {
        if let timezoneIndex = cleanString.firstIndex(of: "+") ?? cleanString.firstIndex(of: "-") {
            cleanString = String(cleanString[..<dotIndex]) + String(cleanString[timezoneIndex...])
        } else {
            cleanString = String(cleanString[..<dotIndex])
        }
    }

    // Fix timezone format: Convert "+00:00" → "+0000"
    if let timezoneStart = cleanString.lastIndex(of: "+") ?? cleanString.lastIndex(of: "-") {
        let timezonePart = cleanString[timezoneStart...]
        if timezonePart.count == 6, timezonePart.contains(":") {
            cleanString = cleanString.replacingOccurrences(of: ":", with: "", range: timezoneStart..<cleanString.endIndex)
        }
    }

    return cleanString
}

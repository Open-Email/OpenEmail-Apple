import Foundation

public func encodeHeaderValue(_ value: String) -> String? {
    var allowedCharacterSet = CharacterSet.urlHostAllowed
    allowedCharacterSet.remove(charactersIn: "=,;")

    return value.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)
}

public func decodeHeaderValue(_ value: String) -> String? {
    return value.removingPercentEncoding
}

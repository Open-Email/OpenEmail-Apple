extension String {
    var cleaned: String {
        replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: " ")
            .joined(separator: " ")
    }
}

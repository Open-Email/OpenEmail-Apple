import Foundation

class RandomWordGenerator {
    static let shared = RandomWordGenerator()
    private let words: [String]

    private init() {
        let file = try? String(contentsOf: URL(fileURLWithPath: "/usr/share/dict/words"))
        words = file?.components(separatedBy: .newlines) ?? []
    }

    func next() -> String? {
        words.randomElement()
    }

    func next(_ count: Int) -> String {
        var items = [String?]()
        for _ in 0..<count {
            items.append(next())
        }

        return items
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

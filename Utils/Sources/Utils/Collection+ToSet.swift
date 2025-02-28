import Foundation

public extension Collection where Element: Hashable {
    func toSet() -> Set<Element> {
        .init(self)
    }
}

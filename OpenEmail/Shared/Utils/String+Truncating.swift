import Foundation

extension String {
    func truncated(to maxLenght: Int, addingEllipsis: Bool = true) -> String {
        let truncated = String(self.prefix(maxLenght))
        if addingEllipsis && truncated.count < self.count {
            return truncated + "…"
        } else {
            return truncated
        }
    }
}

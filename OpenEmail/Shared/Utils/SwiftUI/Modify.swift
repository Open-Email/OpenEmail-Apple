// from: https://stackoverflow.com/a/71203870/379776

import SwiftUI

public extension View {
    /**
     Example:

     ```swift
     Text("Good")
        .modify {
            if #available(iOS 15.0, *) {
                $0.badge(2)
            }
        }
     ```
     */
    @ViewBuilder
    func modify(@ViewBuilder _ transform: (Self) -> (some View)?) -> some View {
        if let view = transform(self), !(view is EmptyView) {
            view
        } else {
            self
        }
    }
}

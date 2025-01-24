import SwiftUI

struct OpenEmailTextFieldLabel: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .textCase(.uppercase)
            .fontWeight(.medium)
    }
}

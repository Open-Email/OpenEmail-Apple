import SwiftUI
import Inspect

struct OpenEmailTextEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: _text)
            .inspect { nsTextView in
                nsTextView.enclosingScrollView?.drawsBackground = false
                nsTextView.enclosingScrollView?.autohidesScrollers = true
                nsTextView.enclosingScrollView?.verticalScroller?.controlSize = .small

                nsTextView.textContainerInset = .init(width: -2, height: 7)
            }
            .padding(.horizontal, .Spacing.xSmall)
            .padding(.vertical, .Spacing.xSmall - 3)
            .overlay {
                RoundedRectangle(cornerRadius: .CornerRadii.default)
                    .stroke(Color.themeSecondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: .CornerRadii.default))
    }
}

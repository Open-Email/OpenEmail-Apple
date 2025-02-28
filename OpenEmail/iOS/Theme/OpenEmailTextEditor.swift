import SwiftUI

struct OpenEmailTextEditor: View {
    var text: Binding<String>

    var body: some View {
        TextEditor(text: text)
            .padding(.Spacing.small)
            .overlay {
                RoundedRectangle(cornerRadius: .CornerRadii.default)
                    .stroke(Color.themeLineGray)
            }
    }
}


import SwiftUI

struct OpenEmailTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
    }
}

extension TextFieldStyle where Self == OpenEmailTextFieldStyle {
    static var openEmail: OpenEmailTextFieldStyle { OpenEmailTextFieldStyle() }
}

#Preview {
    @Previewable @State var text = ""
    TextField("bla", text: $text)
        .textFieldStyle(.openEmail)
        .padding()
        .background(.white)
}

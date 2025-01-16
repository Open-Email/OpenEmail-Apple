import Foundation
import SwiftUI

struct SearchField: View {
    var text: Binding<String>

    var body: some View {
        HStack {
            Image(.searchField)
                .foregroundStyle(.secondary)

            TextField("", text: text, prompt: Text("Search"))
                .textFieldStyle(.plain)
        }
        .padding(8)
        .frame(height: 40)
        .background(.themeBackground)
        .cornerRadius(9)
    }
}

#Preview {
    @Previewable @State var text = ""
    SearchField(text: $text)
        .frame(width: 345)
        .padding()
        .background(.white)
}

import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct InterestsProfileAttributesEditorView: View {
    @Binding var profile: Profile?
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    TextField(
                        "Interests:",
                        text: Binding($profile)?.interests ?? getEmptyBindingForField(
                            ""
                        ),
                        prompt: Text("Enter your interests")
                    )
                    .textFieldStyle(.openEmail)
                    TextField(
                        "Books:",
                        text: Binding($profile)?.books ?? getEmptyBindingForField(
                            ""
                        ),
                        prompt: Text("Enter your favorite books")
                    )
                    .textFieldStyle(.openEmail)
                    TextField(
                        "Movies:",
                        text: Binding($profile)?.movies ?? getEmptyBindingForField(
                            ""
                        ),
                        prompt: Text("Enter your favorite movies")
                    )
                    .textFieldStyle(.openEmail)
                    TextField(
                        "Music:",
                        text: Binding($profile)?.music ?? getEmptyBindingForField(
                            ""
                        ),
                        prompt: Text("Enter your favorite music")
                    )
                    .textFieldStyle(.openEmail)
                    TextField(
                        "Sports:",
                        text: Binding($profile)?.sports ?? getEmptyBindingForField(
                            ""
                        ),
                        prompt: Text("Enter your favorite kinds of sports")
                    )
                    .textFieldStyle(.openEmail)
                }
            }.formStyle(.grouped)
                .background(.regularMaterial)
                .navigationTitle("Interests")
        }
    }
}

#Preview {
    @Previewable @State var profile: Profile? = .makeFake()
    HStack {
        InterestsProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}

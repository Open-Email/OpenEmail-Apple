import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct PersonalProfileAttributesEditorView: View {
    @Binding var profile: Profile?

    var body: some View {
        ScrollView {
            Form {
                Section {
                    TextField(
                        "Gender:",
                        text: Binding($profile)?.gender ?? getEmptyBindingForField(""),
                        prompt: Text("Enter your gender")
                    ).textFieldStyle(.openEmail)
                    TextField(
                        "Relationship status:",
                        text: Binding($profile)?.relationshipStatus ?? getEmptyBindingForField(""),
                        prompt: Text("Single, Married, Divorced, Separated…")
                    )
                        .textFieldStyle(.openEmail)
                    TextField(
                        "Birthday:",
                        text: Binding($profile)?.birthday ?? getEmptyBindingForField(""),
                        prompt: Text("Enter your birthday")
                    )
                        .textFieldStyle(.openEmail)
                    TextField(
                        "Education:",
                        text: Binding($profile)?.education ?? getEmptyBindingForField(""),
                        prompt: Text("Enter your education")
                    )
                        .textFieldStyle(.openEmail)
                    TextField(
                        "Languages:",
                        text: Binding($profile)?.languages ?? getEmptyBindingForField(""),
                        prompt: Text("Enter languages you speak")
                    )
                        .textFieldStyle(.openEmail)
                    TextField(
                        "Places lived:",
                        text: Binding($profile)?.placesLived ?? getEmptyBindingForField(""),
                        prompt: Text("Enter places")
                    )
                        .textFieldStyle(.openEmail)
                    TextField(
                        "Notes:",
                        text: Binding($profile)?.notes ?? getEmptyBindingForField(""),
                        prompt: Text("Enter some notes")
                    ).textFieldStyle(.openEmail)
                }
            }
            .formStyle(.grouped)
            .background(.regularMaterial)
            .navigationTitle("Personal")
        }
    }
}

#Preview {
    @Previewable @State var profile: Profile? = .makeFake()
    HStack {
        PersonalProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}

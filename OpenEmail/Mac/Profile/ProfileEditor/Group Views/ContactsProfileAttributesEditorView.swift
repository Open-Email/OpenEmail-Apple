import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct ContactsProfileAttributesEditorView: View {
    @Binding var profile: Profile?
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    TextField(
                        "Website:",
                        text: Binding($profile)?.website ?? getEmptyBindingForField(
                            ""
                        ),
                        prompt: Text("Enter your website")
                    )
                    .textFieldStyle(.openEmail)
                    TextField(
                        "Location:",
                        text: Binding($profile)?.location ?? getEmptyBindingForField(
                            ""
                        ),
                        prompt: Text("Enter your location")
                    )
                    .textFieldStyle(.openEmail)
                    TextField(
                        "Mailing address:",
                        text: Binding($profile)?.mailingAddress ?? getEmptyBindingForField(
                            ""
                        ),
                        prompt: Text("Enter your mailing address")
                    )
                    .textFieldStyle(.openEmail)
                    TextField(
                        "Phone number:",
                        text: Binding($profile)?.phone ?? getEmptyBindingForField(
                            ""
                        ),
                        prompt: Text("Enter your phone number")
                    )
                    .textFieldStyle(.openEmail)
                    TextField(
                        "Streams:",
                        text: Binding($profile)?.streams ?? getEmptyBindingForField(
                            ""
                        ),
                        prompt: Text("Enter topics")
                    )
                    .textFieldStyle(.openEmail)
                }
            }.formStyle(.grouped)
                .background(.regularMaterial)
                .navigationTitle("Contacts")
        }
    }
}

#Preview {
    @Previewable @State var profile: Profile? = .makeFake()
    HStack {
        ContactsProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}

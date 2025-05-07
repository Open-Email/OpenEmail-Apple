import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct WorkProfileAttributesEditorView: View {
    @Binding var profile: Profile?
    
    var body: some View {
        ScrollView {
            Form {
                TextField("Work:", text: Binding($profile)?.work ?? getEmptyBindingForField(""),
                          prompt: Text("Enter your work"))
                .textFieldStyle(.openEmail)
                TextField("Organization:",
                          text: Binding($profile)?.organization ?? getEmptyBindingForField(""),
                          prompt: Text("Enter your organization"))
                .textFieldStyle(.openEmail)
                TextField("Department:", text: Binding($profile)?.department ?? getEmptyBindingForField(""),
                          prompt: Text("Enter your department"))
                .textFieldStyle(.openEmail)
                TextField("Job title:", text: Binding($profile)?.jobTitle ?? getEmptyBindingForField(""),
                          prompt: Text("Enter your job title"))
                .textFieldStyle(.openEmail)
                
            }
            .formStyle(.grouped)
            .background(.regularMaterial)
            .navigationTitle("Work")
        }
    }
}

#Preview {
    @Previewable @State var profile: Profile? = .makeFake()
    WorkProfileAttributesEditorView(profile: $profile)
}

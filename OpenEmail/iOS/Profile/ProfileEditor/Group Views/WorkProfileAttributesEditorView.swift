import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct WorkProfileAttributesEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        List {
            Section {
                TextField("Work", text: $profile.work)

                VStack(alignment: .leading) {
                    TextField("Organization", text: $profile.organization)
                    ProfileAttributeInfoText(.organization)
                        .padding(.leading, .Spacing.default)
                        .font(.caption)
                }

                TextField("Department", text: $profile.department)

                VStack(alignment: .leading) {
                    TextField("Job title", text: $profile.jobTitle)
                    ProfileAttributeInfoText(.jobTitle)
                        .padding(.leading, .Spacing.default)
                        .font(.caption)
                }
            }
            .listRowSeparator(.hidden)
        }
        .textFieldStyle(.openEmail)
        .listStyle(.plain)
    }
}

#Preview {
    @Previewable @State var profile: Profile = .makeFake()
    WorkProfileAttributesEditorView(profile: $profile)
}

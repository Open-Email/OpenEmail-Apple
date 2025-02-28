import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct PersonalProfileAttributesEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        List {
            Section {
                TextField("Your gender", text: $profile.gender)
                TextField("Relationship status", text: $profile.relationshipStatus)
                TextField("Birthday", text: $profile.birthday)
                TextField("Education", text: $profile.education)
                TextField("Languages", text: $profile.languages)
                TextField("Places lived", text: $profile.placesLived)

                VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                    OpenEmailTextFieldLabel(ProfileAttribute.notes.displayTitle)
                    OpenEmailTextEditor(text: $profile.notes)
                        .frame(height: 120)
                }
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .textFieldStyle(.openEmail)
    }
}

#Preview {
    @Previewable @State var profile: Profile = .makeFake()
    PersonalProfileAttributesEditorView(profile: $profile)
}

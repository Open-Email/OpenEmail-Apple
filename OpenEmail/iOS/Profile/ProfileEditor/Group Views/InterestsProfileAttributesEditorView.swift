import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct InterestsProfileAttributesEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        List {
            Section {
                TextField("Interests", text: $profile.interests)
                TextField("Books", text: $profile.books)
                TextField("Movies", text: $profile.movies)
                TextField("Music", text: $profile.music)
                TextField("Sports", text: $profile.sports)
            }
            .listRowSeparator(.hidden)
        }
        .textFieldStyle(.openEmail)
        .listStyle(.plain)
    }
}

#Preview {
    @Previewable @State var profile: Profile = .makeFake()
    InterestsProfileAttributesEditorView(profile: $profile)
}

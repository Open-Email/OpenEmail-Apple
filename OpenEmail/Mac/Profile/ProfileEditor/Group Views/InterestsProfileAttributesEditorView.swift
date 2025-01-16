import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct InterestsProfileAttributesEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                Text("Interests").font(.title2)

                Grid(horizontalSpacing: .Spacing.large, verticalSpacing: .Spacing.large) {
                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.interests.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter your interests", text: $profile.interests)
                                .textFieldStyle(.openEmail)
                        }
                        .gridCellColumns(2)
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.books.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter your favorite books", text: $profile.books)
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.movies.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter your favorite movies", text: $profile.movies)
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.music.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter your favorite music", text: $profile.music)
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.sports.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter your favorite kind of sports", text: $profile.sports)
                                .textFieldStyle(.openEmail)
                        }
                    }
                }
            }
            .padding(.Spacing.default)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(.themeViewBackground)
    }
}

#Preview {
    @Previewable @State var profile: Profile = .makeFake()
    HStack {
        InterestsProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}

import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct PersonalProfileAttributesEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                Text("Personal").font(.title2)

                Grid(horizontalSpacing: .Spacing.large, verticalSpacing: .Spacing.large) {
                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.gender.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter your gender", text: $profile.gender)
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.relationshipStatus.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Single, Married, Divorced, Separated…", text: $profile.relationshipStatus)
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.birthday.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter birthday", text: $profile.birthday)
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.education.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter your education", text: $profile.education)
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.languages.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter languages", text: $profile.languages)
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.placesLived.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            TextField("Enter places", text: $profile.placesLived)
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            Text(ProfileAttribute.notes.displayTitle)
                                .font(.callout)
                                .textCase(.uppercase)
                                .fontWeight(.medium)

                            OpenEmailTextEditor(text: $profile.notes)
                                .frame(height: 112)
                        }
                        .gridCellColumns(2)
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
        PersonalProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}

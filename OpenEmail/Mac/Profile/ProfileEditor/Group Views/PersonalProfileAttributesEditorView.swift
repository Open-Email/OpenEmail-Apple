import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct PersonalProfileAttributesEditorView: View {
    @Binding var profile: Profile?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                Text("Personal").font(.title2)

                Grid(horizontalSpacing: .Spacing.large, verticalSpacing: .Spacing.large) {
                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.gender.displayTitle)
                            TextField(
                                "Enter your gender",
                                text: Binding($profile)?.gender ?? Binding<String>(
                                    get: {""
                                    },
                                    set: {_ in })
                            )
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.relationshipStatus.displayTitle)
                            TextField(
                                "Single, Married, Divorced, Separated…",
                                text: Binding($profile)?.relationshipStatus ?? Binding<String>(
                                    get: {""
                                    },
                                    set: {_ in })
                            )
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.birthday.displayTitle)
                            TextField(
                                "Enter your birthday",
                                text: Binding($profile)?.birthday ?? Binding<String>(
                                    get: {""
                                    },
                                    set: {_ in })
                            )
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.education.displayTitle)
                            TextField(
                                "Enter your education",
                                text: Binding($profile)?.education ?? Binding<String>(
                                    get: {""
                                    },
                                    set: {_ in })
                            )
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.languages.displayTitle)
                            TextField(
                                "Enter languages you speak",
                                text: Binding($profile)?.languages ?? Binding<String>(
                                    get: {""
                                    },
                                    set: {_ in })
                            )
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.placesLived.displayTitle)
                            TextField(
                                "Enter places",
                                text: Binding($profile)?.placesLived ?? Binding<String>(
                                    get: {""
                                    },
                                    set: {_ in })
                            )
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.notes.displayTitle)
                            OpenEmailTextEditor(
                                text: Binding($profile)?.notes ?? Binding<String>(
                                    get: {""
                                    },
                                    set: {_ in })
                            )
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
    @Previewable @State var profile: Profile? = .makeFake()
    HStack {
        PersonalProfileAttributesEditorView(profile: $profile)
    }
    .frame(height: 800)
}

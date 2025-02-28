import SwiftUI
import OpenEmailModel
import OpenEmailCore

struct WorkProfileAttributesEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .Spacing.default) {
                Text("Work").font(.title2)

                Grid(horizontalSpacing: .Spacing.large, verticalSpacing: .Spacing.large) {
                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.work.displayTitle)
                            TextField("Enter your work", text: $profile.work)
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            HStack {
                                OpenEmailTextFieldLabel(ProfileAttribute.organization.displayTitle)
                                if let info = ProfileAttribute.organization.info {
                                    InfoButton(text: info)
                                }
                            }

                            TextField("Enter your organization", text: $profile.organization)
                                .textFieldStyle(.openEmail)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            OpenEmailTextFieldLabel(ProfileAttribute.department.displayTitle)
                            TextField("Enter your department", text: $profile.department)
                                .textFieldStyle(.openEmail)
                        }

                        VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                            HStack {
                                OpenEmailTextFieldLabel(ProfileAttribute.jobTitle.displayTitle)

                                if let info = ProfileAttribute.jobTitle.info {
                                    InfoButton(text: info)
                                }
                            }

                            TextField("Enter your job title", text: $profile.jobTitle)
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
    WorkProfileAttributesEditorView(profile: $profile)
}

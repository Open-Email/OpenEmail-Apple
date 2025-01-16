import SwiftUI
import OpenEmailCore

struct OnboardingNewAccountView: View {
    @Bindable private var viewModel = OnboardingNewAccountViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.white, .accent)
                    .frame(height: 50)

                Text("Up & Running in Seconds")
                    .multilineTextAlignment(.center)
                    .font(.title)

                VStack(alignment: .leading) {
                    Text("Get a free email address on one of our domains:")
                        .multilineTextAlignment(.leading)
                        .padding(.vertical)

                    HStack {
                        TextField("user name", text: $viewModel.localPart, prompt: Text("user.name"))
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .controlSize(.large)
                            .multilineTextAlignment(.trailing)
                            .labelsHidden()

                        Text("@")

                        Picker(selection: $viewModel.selectedDomainIndex) {
                            ForEach(0..<viewModel.availableDomains.count, id: \.self) { index in
                                Text(viewModel.availableDomains[index])
                            }
                        } label: {
                        }
                    }

                    nameAvailabilityMessage()

                    // TODO:
                    // this could be extracted into a separate onboarding step where the user
                    // can enter basic profile data like name and profile image
                    TextField("Full name", text: $viewModel.fullName)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                        .controlSize(.large)

                    fullNameValidationMessage()

                    Text("You can complete your profile later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                AsyncButton(actionOptions: [.disableButton]) {
                    await viewModel.register()
                } label: {
                    Text("Register")
                        .padding(.horizontal)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .disabled(!viewModel.isValidEmail)

                VStack {
                    Text("Terms of Service")
                    Text("Users are prohibited from engaging in abusive behavior or any illegal activities while using our service, because while we're all for freedom, we draw the line at breaking the law or being a jerk.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity, alignment: .top)
        .blur(radius: viewModel.showProgressIndicator ? 3 : 0)
        .overlay {
            if viewModel.showProgressIndicator {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(viewModel.registrationStatus.statusText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background.opacity(0.75))
            }
        }
        .alert($viewModel.alertConfiguration)
        .animation(.default, value: viewModel.emailAvailabilityMessage)
    }

    @ViewBuilder
    private func nameAvailabilityMessage() -> some View {
        let emailAvailabilityMessage = viewModel.emailAvailabilityMessage
        HStack(spacing: 4) {
            Image(systemName: emailAvailabilityMessage.imageName)
            Text(emailAvailabilityMessage.text)
        }
        .foregroundStyle(emailAvailabilityMessage.color)
        .font(.caption)
    }

    @ViewBuilder
    private func fullNameValidationMessage() -> some View {
        if !viewModel.isValidName {
            HStack(spacing: 4) {
                Image(systemName: "x.circle.fill")
                Text("Name must be at least 6 characters long.")
            }
            .foregroundStyle(.red)
            .font(.caption)
        }
    }
}

#Preview {
    Group {
        OnboardingNewAccountView()
    }
}

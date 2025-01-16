import SwiftUI
import OpenEmailCore

struct OnboardingNewAccountView: View {
    @Binding var onboardingPage: OnboardingPage
    @Bindable private var viewModel = OnboardingNewAccountViewModel()
    @Environment(NavigationState.self) private var navigationState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.large) {
            Image(.logo)
                .padding(.bottom, .Spacing.xSmall)

            // title
            VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                Text("Up & Running in Seconds")
                    .font(.title)

                Text("Get a free email address on one of our domains:")
            }

            // text input fields
            VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                Text("User name")
                    .font(.callout)
                    .textCase(.uppercase)
                    .fontWeight(.medium)

                HStack(spacing: .Spacing.default) {
                    TextField("user.name", text: $viewModel.localPart, prompt: Text("user.name"))
                        .textFieldStyle(.openEmail)

                    Picker(selection: $viewModel.selectedDomainIndex) {
                        ForEach(0..<viewModel.availableDomains.count, id: \.self) { index in
                            Text("@")
                                .foregroundStyle(.secondary) +
                            Text(viewModel.availableDomains[index])
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                    }
                    .buttonStyle(.accessoryBar)
                    .labelsHidden()
                    .fixedSize()
                    .frame(height: 24)
                    .padding(.Spacing.xSmall)
                    .background {
                        RoundedRectangle(cornerRadius: .CornerRadii.default)
                            .fill(.themeBackground)
                    }
                }

                nameAvailabilityMessage()
            }

            VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                Text("Full name")
                    .font(.callout)
                    .textCase(.uppercase)
                    .fontWeight(.medium)

                TextField("Enter your full name", text: $viewModel.fullName)
                    .textFieldStyle(.openEmail)

                fullNameValidationMessage()

                Text("*You can complete your profile later")
                    .foregroundStyle(.secondary)
            }

            // terms of service
            VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                Text("By continuing you agree to the Terms of Service")
                    .fontWeight(.semibold)
                Text("Users are prohibited from engaging in abusive behavior or any illegal activities while using our service, because while we're all for freedom, we draw the line at breaking the law or being a jerk.")
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, .Spacing.xSmall)

            // buttons
            VStack(spacing: .Spacing.default) {
                AsyncButton(actionOptions: [.disableButton]) {
                    navigationState.selectedMessageIDs.removeAll()
                    await viewModel.register()
                } label: {
                    Text("Register")
                        .padding(.horizontal)
                }
                .buttonStyle(OpenEmailButtonStyle(style: .primary))
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isValidEmail)

                Button("Back") {
                    onboardingPage = .initial
                }
                .buttonStyle(OpenEmailButtonStyle(style: .secondary))
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.Spacing.default)
        .padding(.bottom, .Spacing.xSmall)
        .background {
            if colorScheme == .light {
                Color.white
            } else {
                Color.clear
            }
        }
        .blur(radius: viewModel.showProgressIndicator ? 3 : 0)
        .overlay {
            if viewModel.showProgressIndicator {
                VStack(spacing: .Spacing.small) {
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
        HStack(spacing: .Spacing.xxxSmall) {
            Image(systemName: emailAvailabilityMessage.imageName)
            Text(emailAvailabilityMessage.text)
        }
        .foregroundStyle(emailAvailabilityMessage.color)
        .font(.caption)
    }

    @ViewBuilder
    private func fullNameValidationMessage() -> some View {
        if !viewModel.isValidName {
            HStack(spacing: .Spacing.xxxSmall) {
                Image(systemName: "x.circle.fill")
                Text("Name must be at least 6 characters long.")
            }
            .foregroundStyle(.red)
            .font(.caption)
        }
    }
}

#Preview {
    OnboardingNewAccountView(onboardingPage: .constant(.existingAccount))
        .frame(width: 400)
        .environment(NavigationState())
}

import SwiftUI
import OpenEmailCore
import Logging
import Inspect

struct OnboardingExistingAccountView: View {
    let emailAddress: String
    @Environment(NavigationState.self) private var navigationState
    @Binding var onboardingPage: OnboardingPage

    @State private var viewModel = OnboardingExistingAccountViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: .Spacing.large) {
            Image(.logo)
                .padding(.bottom, .Spacing.xSmall)

            VStack(alignment: .leading, spacing: .Spacing.xSmall) {
                Text(emailAddress)
                    .font(.title)

                Text("Enter your private keys")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading) {
                Text("Private Encryption Key")
                    .textCase(.uppercase)
                    .font(.callout)
                    .fontWeight(.medium)
                keyTextEditor(text: $viewModel.privateEncryptionKey)
            }

            VStack(alignment: .leading) {
                Text("Private Signing Key")
                    .textCase(.uppercase)
                    .font(.callout)
                    .fontWeight(.medium)
                keyTextEditor(text: $viewModel.privateSigningKey)
            }

            VStack(spacing: .Spacing.default) {
                AsyncButton("Authenticate") {
                    // Clear up any previous state
                    navigationState.selectedMessageIDs.removeAll()

                    await viewModel.authenticate(emailAddress: emailAddress)
                }
                .buttonStyle(OpenEmailButtonStyle(style: .primary))
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .disabled(!viewModel.hasBothKeys)
                .padding(.top, .Spacing.xSmall)

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
        .blur(radius: viewModel.isAuthorizing ? 3 : 0)
        .overlay {
            if viewModel.isAuthorizing {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background.opacity(0.75))
            }
        }
        .alert($viewModel.alertConfiguration)
    }

    @ViewBuilder
    private func keyTextEditor(text: Binding<String>) -> some View {
        HStack(alignment: .top, spacing: .Spacing.xxxSmall) {
            Image(.key)
                .foregroundStyle(.secondary)

            TextField("", text: text, prompt: Text("cJGp...QPtkA=="), axis: .vertical)
                .inspect {
                    $0.lineBreakMode = .byCharWrapping
                }
                .textFieldStyle(.plain)
                .monospaced()
                .lineLimit(3, reservesSpace: true)
                .autocorrectionDisabled()
                .padding(.top, 3)
        }
        .padding(.horizontal, .Spacing.xSmall)
        .padding(.vertical, .Spacing.xSmall - 3)
        .background(.themeBackground)
        .clipShape(RoundedRectangle(cornerRadius: .CornerRadii.default))
    }
}

#Preview {
    OnboardingExistingAccountView(emailAddress: "test@test.com", onboardingPage: .constant(.existingAccount))
        .frame(width: 400)
        .environment(NavigationState())
}

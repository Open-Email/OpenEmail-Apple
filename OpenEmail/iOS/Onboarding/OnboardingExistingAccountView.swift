import SwiftUI
import CodeScanner
import Logging

struct OnboardingExistingAccountView: View {
    var emailAddress: String

    @State private var viewModel = OnboardingExistingAccountViewModel()
    @State private var isPresentingScanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                OnboardingHeaderView()

                VStack(alignment: .leading, spacing: .Spacing.default) {
                    Text("Enter your private keys")
                        .font(.title2)

                    VStack(alignment: .leading, spacing: .Spacing.small) {
                        Text("Your account")
                            .foregroundStyle(.secondary)

                        HStack(spacing: .Spacing.small) {
                            ProfileImageView(emailAddress: emailAddress, size: .Spacing.xxxLarge)
                            Text(emailAddress)
                                .font(.title3)
                        }
                    }

                    VStack(alignment: .leading, spacing: .Spacing.large) {
                        VStack(alignment: .leading) {
                            OpenEmailTextFieldLabel("Private Encryption Key")
                            keyTextEditor(text: $viewModel.privateEncryptionKey)
                        }

                        VStack(alignment: .leading) {
                            OpenEmailTextFieldLabel("Private Signing Key")
                            keyTextEditor(text: $viewModel.privateSigningKey)
                        }
                    }
                    .padding(.top, .Spacing.default)
                    .disabled(viewModel.isAuthorizing)

                    VStack(spacing: .Spacing.default) {
                        AsyncButton(actionOptions: [.showProgressView]) {
                            await viewModel.authenticate(emailAddress: emailAddress)
                        } label: {
                            Text("Authenticate")
                                .padding(.horizontal)
                        }
                        .buttonStyle(OpenEmailButtonStyle(style: .primary))
                        .keyboardShortcut(.defaultAction)
                        .disabled(!viewModel.hasBothKeys)

                        Button {
                            isPresentingScanner = true
                        } label: {
                            Text("Scan QR-code")
                        }
                        .buttonStyle(OpenEmailButtonStyle(style: .secondary))
                    }
                    .padding(.vertical, .Spacing.xLarge)
                    .disabled(viewModel.isAuthorizing)
                }
                .padding([.leading, .trailing, .bottom], .Spacing.default)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .scrollBounceBehavior(.basedOnSize)
        .ignoresSafeArea(edges: .top)
        .alert($viewModel.alertConfiguration)
        .sheet(isPresented: $isPresentingScanner) {
            CodeScannerView(
                codeTypes: [.qr],
                showViewfinder: true,
                shouldVibrateOnSuccess: true
            ) { response in
                switch response {
                case let .success(result):
                    handleScannedQRCode(result.string)
                    isPresentingScanner = false
                case let .failure(error):
                    // TODO: show error
                    Log.error("Could not scan QR code: \(error)")
                }
            }
        }
    }

    private func handleScannedQRCode(_ code: String) {
        let components = code.components(separatedBy: ":")
        if components.count == 2 {
            viewModel.privateEncryptionKey = components[0]
            viewModel.privateSigningKey = components[1]
        } else {
            // TODO: show error
            Log.error("Invalid QR code: \(code)")
        }
    }

    @ViewBuilder
    private func keyTextEditor(text: Binding<String>) -> some View {
        HStack(alignment: .top, spacing: .Spacing.xxxSmall) {
            Image(.key)
                .foregroundStyle(.secondary)

            TextField("", text: text, prompt: Text("cJGp...QPtkA=="), axis: .vertical)
                .textFieldStyle(.plain)
                .monospaced()
                .lineLimit(3)
                .autocorrectionDisabled()
                .padding(.top, 2)
        }
        .padding(.horizontal, .Spacing.small)
        .padding(.vertical, .Spacing.small)
        .background(.themeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }
}

#Preview {
    OnboardingExistingAccountView(emailAddress: "test@test.com")
}

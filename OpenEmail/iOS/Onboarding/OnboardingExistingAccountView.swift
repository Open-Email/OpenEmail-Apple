import SwiftUI
import CodeScanner
import Logging

struct OnboardingExistingAccountView: View {
    var emailAddress: String

    @State private var viewModel = OnboardingExistingAccountViewModel()
    @State private var isPresentingScanner = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white, .accent)
                .frame(height: 50)

            Text(emailAddress)
                .font(.title)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Enter your private keys:")
                    Spacer()
                    Button {
                        isPresentingScanner = true
                    } label: {
                        Image(systemName: "qrcode")
                    }
                }

                GroupBox {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Label("Private Encryption Key", systemImage: "key.horizontal")
                            keyTextEditor(text: $viewModel.privateEncryptionKey)
                        }

                        VStack(alignment: .leading) {
                            Label("Private Signing Key", systemImage: "pencil")
                            keyTextEditor(text: $viewModel.privateSigningKey)
                        }
                    }
                }

                HStack {
                    AsyncButton {
                        await viewModel.authenticate(emailAddress: emailAddress)
                    } label: {
                        Text("Authenticate")
                            .padding(.horizontal)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    .disabled(!viewModel.hasBothKeys)
                    .padding()
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .padding(.top, 50)
        .padding(.bottom, 20)
        .padding(.horizontal)
        .frame(maxHeight: .infinity)
        .blur(radius: viewModel.isAuthorizing ? 3 : 0)
        .overlay {
            if viewModel.isAuthorizing {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background.opacity(0.75))
            }
        }
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
        // TODO: figure out how to wrap by character and not by word

        TextField("", text: text, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(3, reservesSpace: true)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .background(.quinary)
            .fontDesign(.monospaced)
    }
}

#Preview {
    OnboardingExistingAccountView(emailAddress: "test@test.com")
}

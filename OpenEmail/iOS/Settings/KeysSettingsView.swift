import SwiftUI
import Utils
import OpenEmailCore

struct KeysSettingsView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) var registeredEmailAddress: String?
    @AppStorage(UserDefaultsKeys.publicEncryptionKey) var publicEncryptionKey: String?
    @AppStorage(UserDefaultsKeys.publicSigningKey) var publicSigningKey: String?

    private let keysStore = standardKeyStore()

    var body: some View {
        let keys = try? keysStore.getKeys()
        let privateSigningKey = keys?.privateSigningKey
        let privateEncryptionKey = keys?.privateEncryptionKey

        Form {
            if let privateSigningKey, let privateEncryptionKey {
                qrCode(
                    privateSigningKey: privateSigningKey,
                    privateEncryptionKey: privateEncryptionKey
                )
                .listRowBackground(Color.clear)
            }

            Section("Private Keys") {
                keyRow(title: "Private Signing Key", key: privateSigningKey)
                keyRow(title: "Private Encryption Key", key: privateEncryptionKey)
            }

            Section("Public Keys") {
                keyRow(title: "Public Signing Key", key: publicSigningKey)
                keyRow(title: "Public Encryption Key", key: publicSigningKey)
            }
        }
        .formStyle(.grouped)
        .textSelection(.enabled)
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("Keys")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func keyRow(title: String, key: String?) -> some View {
        VStack(alignment: .leading) {
            Text(title)
            Text(key ?? "-")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func qrCode(privateSigningKey: String, privateEncryptionKey: String) -> some View {
        let string = [privateEncryptionKey, privateSigningKey].joined(separator: ":")
        if let qrCode = QRCodeGenerator.generateQRCode(from: string) {
            VStack {
                qrCode.swiftUIImage
                    .padding(10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    KeysSettingsView()
}

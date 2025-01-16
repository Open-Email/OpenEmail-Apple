import SwiftUI
import Utils
import OpenEmailCore

struct KeysSettingsView: View {
    @AppStorage(UserDefaultsKeys.registeredEmailAddress) var registeredEmailAddress: String?
    @AppStorage(UserDefaultsKeys.publicEncryptionKey) var publicEncryptionKey: String?
    @AppStorage(UserDefaultsKeys.publicSigningKey) var publicSigningKey: String?

    private let keysStore = standardKeyStore()

    var body: some View {
        if registeredEmailAddress != nil {
            let keys = try? keysStore.getKeys()
            let privateSigningKey = keys?.privateSigningKey
            let privateEncryptionKey = keys?.privateEncryptionKey

            VStack {
                if let privateSigningKey, let privateEncryptionKey {
                    qrCode(privateSigningKey: privateSigningKey, privateEncryptionKey: privateEncryptionKey)
                }
                
                Form {
                    Section("Private Keys") {
                        LabeledContent("Private Signing Key", value: privateSigningKey ?? "-")
                        LabeledContent("Private Encryption Key", value: privateEncryptionKey ?? "-")
                    }
                    
                    Section("Public Keys") {
                        LabeledContent("Public Signing Key", value: publicSigningKey ?? "-")
                        LabeledContent("Public Encryption Key", value: publicEncryptionKey ?? "-")
                    }
                }
                .formStyle(.grouped)
                .scrollBounceBehavior(.basedOnSize)
            }
            .fixedSize()
        } else {
            Text("No user logged in")
                .foregroundStyle(.secondary)
                .bold()
        }
    }

    @ViewBuilder
    private func qrCode(privateSigningKey: String, privateEncryptionKey: String) -> some View {
        let string = [privateEncryptionKey, privateSigningKey].joined(separator: ":")
        if let qrCode = QRCodeGenerator.generateQRCode(from: string) {
            qrCode.swiftUIImage
                .padding(10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    KeysSettingsView()
}

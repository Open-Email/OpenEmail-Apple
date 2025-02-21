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

        List {
            if let privateSigningKey, let privateEncryptionKey {
                qrCode(
                    privateSigningKey: privateSigningKey,
                    privateEncryptionKey: privateEncryptionKey
                )
                .listRowBackground(Color.themeBackground)
                .listRowSeparator(.hidden)
            }

            Section("Private Keys") {
                keyRow(title: "Private Signing Key", key: privateSigningKey)
                keyRow(title: "Private Encryption Key", key: privateEncryptionKey)
            }
            .listRowSeparator(.hidden)

            Section("Public Keys") {
                keyRow(title: "Public Signing Key", key: publicSigningKey)
                keyRow(title: "Public Encryption Key", key: publicSigningKey)
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.grouped)
        .textSelection(.enabled)
        .scrollBounceBehavior(.basedOnSize)
        .scrollContentBackground(.hidden)
        .navigationTitle("Keys")
    }

    @ViewBuilder
    private func keyRow(title: String, key: String?) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title).font(.headline)
                Spacer()

                if let key {
                    Button("Copy", image: .copy) {
                        UIPasteboard.general.string = key
                    }
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    .frame(width: 24, height: 24)
                }
            }
            Text(key ?? "-")
        }
    }

    @ViewBuilder
    private func qrCode(privateSigningKey: String, privateEncryptionKey: String) -> some View {
        let string = [privateEncryptionKey, privateSigningKey].joined(separator: ":")
        if let qrCode = QRCodeGenerator.generateQRCode(from: string) {
            VStack {
                qrCode.swiftUIImage
                    .padding(.Spacing.small)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: .CornerRadii.default))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .Spacing.xLarge)
        }
    }
}

#Preview {
    KeysSettingsView()
}

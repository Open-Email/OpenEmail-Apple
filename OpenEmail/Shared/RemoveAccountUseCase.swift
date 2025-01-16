import Foundation
import Logging
import OpenEmailPersistence
import OpenEmailCore
import Utils

class RemoveAccountUseCase {
    private let keysStore: KeysStoring

    init(keyStore: KeysStoring = standardKeyStore()) {
        self.keysStore = keyStore
    }

    func removeAccount() {
        let defaults = UserDefaults.standard
        guard let registeredEmailAddress = defaults.registeredEmailAddress else { return }

        do {
            try keysStore.deleteKeys()

            defaults.publicEncryptionKey = ""
            defaults.publicSigningKey = ""
            defaults.publicEncryptionKeyId = ""
        } catch {
            Log.error("Could not delete keys:", context: error)
        }
        defaults.registeredEmailAddress = nil

        let fm = FileManager.default
        let messageFolderUrl = fm.messagesFolderURL(userAddress: registeredEmailAddress)
        try? fm.removeItem(at: messageFolderUrl)

        Task {
            try await PersistedStore.shared.deleteAllData()
        }
    }
}

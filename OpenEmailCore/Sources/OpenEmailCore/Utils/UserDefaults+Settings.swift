import Foundation

public enum UserDefaultsKeys {
    public static let registeredEmailAddress = "registeredEmailAddress"
    public static let publicEncryptionKey = "publicEncryptionKey"
    public static let publicEncryptionKeyId = "publicEncryptionKeyId"
    public static let publicSigningKey = "publicSigningKey"
    public static let notificationFetchingInterval = "notificationFetchingInterval"
    public static let automaticTrashDeletionDays = "automaticTrashDeletionDays"
    public static let profileName = "profileName"
    public static let useKeychainStore = "useKeychainStore"
    public static let trustedDomains = "trustedDomains"
    public static let attachmentsDownloadThresholdInMegaByte = "attachmentsDownloadThresholdInMegaByte"
}

public extension UserDefaults {
    func registerDefaults() {
        register(defaults: [
            UserDefaultsKeys.notificationFetchingInterval: 15,
            UserDefaultsKeys.automaticTrashDeletionDays: -1,
            UserDefaultsKeys.attachmentsDownloadThresholdInMegaByte: 5
        ])
    }

    @objc
    var registeredEmailAddress: String? {
        set { set(newValue, forKey: UserDefaultsKeys.registeredEmailAddress) }
        get { string(forKey: UserDefaultsKeys.registeredEmailAddress) }
    }

    var publicEncryptionKey: String? {
        set { set(newValue, forKey: UserDefaultsKeys.publicEncryptionKey) }
        get { string(forKey: UserDefaultsKeys.publicEncryptionKey) }
    }

    var publicEncryptionKeyId: String? {
        set { set(newValue, forKey: UserDefaultsKeys.publicEncryptionKeyId) }
        get { string(forKey: UserDefaultsKeys.publicEncryptionKeyId) }
    }

    var publicSigningKey: String? {
        set { set(newValue, forKey: UserDefaultsKeys.publicSigningKey) }
        get { string(forKey: UserDefaultsKeys.publicSigningKey) }
    }

    @objc
    var notificationFetchingInterval: Int {
        set { set(newValue, forKey: UserDefaultsKeys.notificationFetchingInterval) }
        get { integer(forKey: UserDefaultsKeys.notificationFetchingInterval) }
    }

    var automaticTrashDeletionDays: Int {
        set { set(newValue, forKey: UserDefaultsKeys.automaticTrashDeletionDays) }
        get { integer(forKey: UserDefaultsKeys.automaticTrashDeletionDays) }
    }

    var profileName: String? {
        set { set(newValue, forKey: UserDefaultsKeys.profileName) }
        get { string(forKey: UserDefaultsKeys.profileName) }
    }

    var useKeychainStore: Bool {
        set { set(newValue, forKey: UserDefaultsKeys.useKeychainStore) }
        get { bool(forKey: UserDefaultsKeys.useKeychainStore) }
    }

    var attachmentsDownloadThresholdInMegaByte: Int {
        set { set(newValue, forKey: UserDefaultsKeys.attachmentsDownloadThresholdInMegaByte) }
        get { integer(forKey: UserDefaultsKeys.attachmentsDownloadThresholdInMegaByte) }
    }

    var trustedDomains: [String] {
        get {
            if
                let trustedDomainsRaw = UserDefaults.standard.string(forKey: "trustedDomains"),
                let trustedDomains = [String](rawValue: trustedDomainsRaw)
            {
                return trustedDomains
            }
            return []
        }
    }
}

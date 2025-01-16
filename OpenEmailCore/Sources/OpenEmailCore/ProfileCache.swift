import Foundation
import Cache

class ProfileCache {
    private let storage: Storage<String, Profile>?

    init() {
        let diskConfig = DiskConfig(name: "profile-images", expiry: .seconds(24 * 60 * 60)) // 24 hours lifetime
        let memoryConfig = MemoryConfig(expiry: .seconds(1 * 60 * 60), countLimit: 10) // 1 hour lifetime
        storage = try? Storage(diskConfig: diskConfig, memoryConfig: memoryConfig, transformer: TransformerFactory.forCodable(ofType: Profile.self))
    }

    func setProfile(_ profile: Profile) {
        try? storage?.setObject(profile, forKey: profile.address.address)
    }

    func profile(for emailAddress: EmailAddress) -> Profile? {
        try? storage?.object(forKey: emailAddress.address)
    }
}

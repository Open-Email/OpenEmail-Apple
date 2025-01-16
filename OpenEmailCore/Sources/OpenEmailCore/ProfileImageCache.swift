import Foundation
import Cache

class ProfileImageCache {
    private let storage: Storage<URL, Data>?

    init() {
        let diskConfig = DiskConfig(name: "profile-images", expiry: .seconds(15 * 60)) // 15 minutes lifetime
        let memoryConfig = MemoryConfig(expiry: .seconds(15 * 60), countLimit: 10) // 15 minutes lifetime
        storage = try? Storage(diskConfig: diskConfig, memoryConfig: memoryConfig, transformer: TransformerFactory.forData())
    }

    func setImageData(_ data: Data, for url: URL) {
        try? storage?.setObject(data, forKey: url)
    }

    func imageData(for url: URL) -> Data? {
        return try? storage?.object(forKey: url)
    }

    func removeImageData(for url: URL) {
        try? storage?.removeObject(forKey: url)
    }
}

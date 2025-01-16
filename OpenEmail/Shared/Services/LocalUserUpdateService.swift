import Foundation
import Combine
import Utils
import OpenEmailCore

class LocalUserUpdateService {
    private var subscriptions = Set<AnyCancellable>()

    init() {
        UserDefaults.standard.publisher(for: \.registeredEmailAddress)
            .removeDuplicates()
            .sink { _ in
                self.update()
            }
            .store(in: &subscriptions)
    }

    private func update() {
        LocalUser.update()
    }
}

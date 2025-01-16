import Foundation
import Observation
import OpenEmailCore
import AppKit
import SwiftUI
import Combine
import Logging

@Observable
class ProfileEditorViewModel {
    var profile: Profile?
    var isLoadingProfile = false
    var didChangeImage = false
    var profileImage: NSImage?

    @ObservationIgnored
    @Injected(\.client) private var client

    private var updateTrigger = PassthroughSubject<Void, Never>()
    private var updateCancellable: AnyCancellable?

    init() {
        updateCancellable = updateTrigger
            .debounce(for: 1, scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.doUpdateProfile()
            }
    }

    func loadProfile() async throws {
        guard let localUser = LocalUser.current else { return }
        isLoadingProfile = true
        profile = try await client.fetchProfile(address: localUser.address, force: true)
        isLoadingProfile = false
    }

    func updateProfile() {
        updateTrigger.send()
    }

    private func doUpdateProfile() {
        guard
            let localUser = LocalUser.current,
            let profile
        else {
            return
        }

        Log.debug("updating profile")

        Task {
            do {
                if didChangeImage {
                    if let profileImage {
                        try await client.uploadProfileImage(localUser: localUser, image: profileImage)
                    } else {
                        try await client.deleteProfileImage(localUser: localUser)
                    }

                    didChangeImage = false
                }

                try await client.uploadProfile(localUser: localUser, profile: profile)
                UserDefaults.standard.profileName = profile.attributes[.name]
            } catch {
                // TODO: show error in UI?
                Log.error("Could not update profile: \(error)")
            }
        }
    }
}

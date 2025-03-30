import Foundation
import OpenEmailCore
import Utils

#if DEBUG
class EmailClientMock: Client {
    func updateBroadcastsForContact(localUser: LocalUser, address: EmailAddress, allowBroadcasts: Bool) async throws {
        
    }
    
    func getLinks(localUser: OpenEmailCore.LocalUser) async throws -> [Link]? {
        nil
    }

    func authenticate(emailAddress: EmailAddress, privateEncryptionKey: String, privateSigningKey: String) async throws -> (LocalUser?, [String]) {
        (nil, [])
    }

    func generateLocalUser(address: String, name: String?) throws -> LocalUser {
        try LocalUser.makeRandom()
    }

    func registerAccount(user: LocalUser, fullName: String?) async throws {
    }

    func lookupAddressAvailability(address: EmailAddress) async throws -> Bool {
        false
    }

    func lookupHostsDelegations(address: EmailAddress) async throws -> [String] {
        []
    }

    func fetchNotifications(localUser: LocalUser) async throws {
    }

    func notifyReaders(readersAddresses: [EmailAddress], localUser: LocalUser) async throws {
    }

    func executeNotifications(localUser: LocalUser) async throws -> [String] {
        []
    }

    func fetchRemoteMessages(localUser: LocalUser, authorProfile: Profile) async throws {
    }

    func fetchRemoteBroadcastMessages(localUser: LocalUser, authorProfile: Profile) async throws {
    }

    func fetchLocalMessages(localUser: LocalUser, localProfile: Profile) async throws -> [String] {
        []
    }

    func uploadPrivateMessage(localUser: LocalUser, subject: String, readersAddresses: [EmailAddress], body: Data, urls: [URL], progressHandler: @escaping (Double) -> Void) async throws -> String? {
        nil
    }

    func uploadBroadcastMessage(localUser: LocalUser, subject: String, body: Data, urls: [URL], progressHandler: @escaping (Double) -> Void) async throws -> String? {
        nil
    }

    func recallAuthoredMessage(localUser: LocalUser, messageId: String) async throws {
    }

    func fetchMessageDeliveryInformation(localUser: LocalUser, messageId: String) async throws -> [(String, Date)]? {
        nil
    }

    var stubFetchedProfile: Profile?
    func fetchProfile(address: EmailAddress, force: Bool) async throws -> Profile? {
        stubFetchedProfile
    }

    func fetchProfileImage(address: EmailAddress, force: Bool) async throws -> Data? {
        nil
    }

    func uploadProfile(localUser: LocalUser, profile: Profile) async throws {
    }

    func uploadProfileImage(localUser: LocalUser, imageData: Data) async throws {
    }

    func deleteProfileImage(localUser: LocalUser) async throws {
    }

    func isAddressInContacts(localUser: LocalUser, address: EmailAddress) async throws -> Bool {
        false
    }

    func storeContact(localUser: LocalUser, address: EmailAddress) async throws {
    }

    func fetchContacts(localUser: LocalUser) async throws -> [EmailAddress] {
        []
    }

    func deleteContact(localUser: LocalUser, address: EmailAddress) async throws {
    }

    func syncContacts(localUser: LocalUser) async throws {
    }

    func downloadFileAttachment(messageIds: [String], parentId: String, localUser: LocalUser, filename: String) async throws {
    }
}
#endif

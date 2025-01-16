import Foundation

public extension FileManager {
    func documentsDirectoryUrl() -> URL {
        try! url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    func messagesFolderURL(userAddress: String) -> URL {
        documentsDirectoryUrl()
            .appending(path: MESSAGES_DIRECTORY, directoryHint: .isDirectory)
            .appending(path: userAddress, directoryHint: .isDirectory)
    }

    func messageFolderURL(userAddress: String, messageID: String) ->  URL {
        messagesFolderURL(userAddress: userAddress)
            .appending(path: messageID, directoryHint: .isDirectory)
    }
}

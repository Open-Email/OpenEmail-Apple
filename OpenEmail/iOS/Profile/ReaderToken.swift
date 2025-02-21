import Foundation
import SwiftUI

struct ReaderToken: TokenTextFieldToken {
    var id: UUID = UUID()
    var value: String
    var displayName: String?
    var isSelected: Bool = false
    var convertedToToken = true
    var isValid: Bool?
    var isMe: Bool
    var isInMyContacts = false

    var icon: ImageResource? {
        if isMe || isInMyContacts {
            .readerInContacts
        } else {
            .readerNotInContacts
        }
    }

    static func empty(isSelected: Bool) -> Self {
        ReaderToken(value: "", isSelected: isSelected, convertedToToken: false, isMe: false)
    }
}

struct AllContactsToken: TokenTextFieldToken {
    var id: UUID = UUID()
    var value: String = ""
    let displayName: String? = "All contacts"
    var isSelected = false
    var convertedToToken = true
    var isValid: Bool? = true
    let icon: ImageResource? = nil

    static func empty(isSelected: Bool) -> AllContactsToken {
        AllContactsToken()
    }
}

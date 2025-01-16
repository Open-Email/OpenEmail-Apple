import Foundation
import SwiftUI

struct ReaderToken: TokenTextFieldToken {
    var id: UUID = UUID()
    var value: String
    var displayName: String?
    var isSelected: Bool = false
    var convertedToToken = true
    var isValid: Bool?
    var isInMyContacts = false
    var isInOtherContacts: Bool?

    static func empty(isSelected: Bool) -> Self {
        ReaderToken(value: "", isSelected: isSelected, convertedToToken: false)
    }

    var color: Color {
        if isValid == false {
            return .red
        }

        if value.lowercased() == UserDefaults.standard.registeredEmailAddress {
            return .green
        }

        if isInMyContacts {
            if isInOtherContacts == true {
                return .accentColor
            }
        }

        return .gray
    }
}

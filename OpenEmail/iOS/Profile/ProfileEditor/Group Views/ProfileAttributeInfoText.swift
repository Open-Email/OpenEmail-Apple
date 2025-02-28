import SwiftUI
import OpenEmailCore

struct ProfileAttributeInfoText: View {
    private let profileAttribute: ProfileAttribute

    init(_ profileAttribute: ProfileAttribute) {
        self.profileAttribute = profileAttribute
    }

    var body: some View {
        if let info = profileAttribute.info {
            Text(info).foregroundStyle(.secondary)
        }
    }
}

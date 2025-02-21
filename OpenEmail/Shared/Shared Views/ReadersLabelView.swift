import SwiftUI

struct ReadersLabelView: View {
    var body: some View {
        HStack(spacing: .Spacing.xxxSmall) {
            Image(.readers)
            Text("Readers:")
        }
        .foregroundStyle(.secondary)
        #if os(iOS)
        .font(.subheadline)
        #endif
    }
}

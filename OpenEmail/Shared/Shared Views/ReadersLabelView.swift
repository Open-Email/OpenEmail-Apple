import SwiftUI

struct ReadersLabelView: View {
    var body: some View {
        HStack(spacing: .Spacing.xxxSmall) {
            Image(.readers)
            Text("Readers:").font(.body)
        }
        .foregroundStyle(.secondary)
        #if os(iOS)
        .font(.subheadline)
        #endif
    }
}

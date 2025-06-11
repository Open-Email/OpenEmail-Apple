import SwiftUI

struct ReadersLabelView: View {
    var body: some View {
        HStack(spacing: .Spacing.xxxSmall) {
            Image(.readers)
            Text("Readers:")
#if os(iOS)
                .font(.subheadline)
#else
                .font(.body)
#endif
        }
        .foregroundStyle(.secondary)
    }
}

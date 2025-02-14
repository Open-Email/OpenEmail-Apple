import SwiftUI

struct RoundToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .colorScheme(.dark)
    }
}

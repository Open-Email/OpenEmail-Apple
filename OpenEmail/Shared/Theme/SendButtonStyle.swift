import SwiftUI

struct SendButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: .Spacing.xxSmall) {
            Image(.send)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
            configuration.label
        }
        .foregroundStyle(.white)
        .padding(.vertical, .Spacing.xSmall)
        .padding(.leading, 10)
        .padding(.trailing, .Spacing.default)
        .background(Capsule().fill(configuration.isPressed ? Color.themeBlueHover : Color.themeBlue))
        .opacity(isEnabled ? 1 : 0.5)
    }
}

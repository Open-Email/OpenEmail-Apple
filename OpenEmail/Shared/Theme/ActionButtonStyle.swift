import Foundation
import SwiftUI

struct ActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    private let isImageOnly: Bool
    private let height: CGFloat
    private let isProminent: Bool

    init(isImageOnly: Bool = false, height: CGFloat = 26, isProminent: Bool = false) {
        self.isImageOnly = isImageOnly
        self.height = height
        self.isProminent = isProminent
    }

    private func overlayColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return Color(NSColor(white: 0.3, alpha: 0.8))
        } else {
            return isPressed ? .white.opacity(0.5) : .clear
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.medium)
            .foregroundStyle(isProminent ? .themeBackground : .themePrimary)
            .padding(.leading, isImageOnly ? .Spacing.small : .Spacing.xSmall)
            .padding(.trailing, .Spacing.small)
            .padding(.vertical, .Spacing.xxxSmall)
            .frame(height: height)
            .background {
                Capsule(style: .circular)
                    .fill(isProminent ? .themePrimary : .actionButtonBackground)
                    .stroke(.actionButtonOutline)
            }
            .overlay {
                Capsule(style: .circular)
                    .fill(overlayColor(isPressed: configuration.isPressed))
            }
    }
}

#Preview {
    HStack {
        Button {
        } label: {
            HStack(spacing: .Spacing.xxSmall) {
                Image(.reply)
                Text("Reply")
            }
        }

        Button {
        } label: {
            HStack(spacing: .Spacing.xxSmall) {
                Image(.forward)
                Text("Forward")
            }
        }
        .disabled(true)

        Button {
        } label: {
            Image(.scopeTrash)
        }
        .buttonStyle(ActionButtonStyle(isImageOnly: true))

        Button {
        } label: {
            HStack(spacing: .Spacing.xxSmall) {
                Image(.createMessage)
                Text("Create message")
            }
        }
        .buttonStyle(ActionButtonStyle(isProminent: true))
    }
    .buttonStyle(ActionButtonStyle())
    .padding()
}

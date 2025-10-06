import SwiftUI

struct OpenEmailButtonStyle: ButtonStyle {
    enum Style {
        case primary
        case secondary

        var defaultTintColor: Color {
            switch self {
            case .primary: .accentColor
            case .secondary: .themeLineGray
            }
        }
    }

    private let style: Style
    private let showsActivityIndicator: Bool
    private let tintColorOverride: Color?

    init(
        style: Style,
        showsActivityIndicator: Bool = false,
        tintColorOverride: Color? = nil
    ) {
        self.style = style
        self.showsActivityIndicator = showsActivityIndicator
        self.tintColorOverride = tintColorOverride
    }

    func makeBody(configuration: Configuration) -> some View {
        OpenEmailButton(
            configuration: configuration,
            style: style,
            showsActivityIndicator: showsActivityIndicator,
            tintColor: tintColorOverride ?? style.defaultTintColor
        )
    }

    private struct OpenEmailButton: View {
        let configuration: ButtonStyle.Configuration
        let style: OpenEmailButtonStyle.Style
        let showsActivityIndicator: Bool
        let tintColor: Color
        @State private var isHovering = false

        @Environment(\.isEnabled) private var isEnabled: Bool

        private var strokeWidth: CGFloat {
            style == .primary ? 0 : 1
        }

        private var brightness: CGFloat {
            if configuration.isPressed {
                return -0.25
            } else if isHovering {
                return -0.1
            } else {
                return 0
            }
        }

        private var foregroundColor: Color {
            switch style {
            case .primary:
                if isEnabled {
                    Color.white
                } else {
                    Color.primary
                }
            case .secondary: Color.primary
            }
        }

        private var backgroundColor: Color {
            switch style {
            case .primary: tintColor
            case .secondary: Color.clear
            }
        }

        private var strokeColor: Color {
            style == .primary ? .clear : tintColor
        }

        var body: some View {
            ZStack(alignment: .leading) {
                configuration.label
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(foregroundColor)
                    .background(backgroundColor)
                    .cornerRadius(.CornerRadii.default)
                    .overlay(
                        RoundedRectangle(cornerRadius: .CornerRadii.default)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
                    .brightness(brightness)
                    .opacity(isEnabled ? 1.0 : 0.3)

                if showsActivityIndicator {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 10)
                }
            }
            .animation(.easeOut, value: isHovering)
            .onHover {
                isHovering = $0
            }
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        Button(action: {}) {
            Text("Click Me")
        }
        .buttonStyle(OpenEmailButtonStyle(style: .primary, showsActivityIndicator: true))
        .disabled(true)

        Button(action: {}) {
            Text("Click Me")
        }
        .buttonStyle(OpenEmailButtonStyle(style: .primary))

        Button(action: {}) {
            Text("Click Me")
        }
        .buttonStyle(OpenEmailButtonStyle(style: .secondary))

        Button(action: {}) {
            Text("Click Me")
        }
        .buttonStyle(OpenEmailButtonStyle(style: .primary, tintColorOverride: .green))
    }
    .padding()
    .frame(width: 300)
}

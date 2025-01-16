import SwiftUI

struct SnackBarConfiguration {
    var title: String
    var message: String?
    var type: SnackBarType
    var duration: TimeInterval? = 5 // set to `nil` if the bar shouldn't dismiss automatically
}

enum SnackBarType {
    case info
    case warning
    case success
    case error

    @ViewBuilder
    func icon() -> some View {
        switch self {
        case .info: InfoIcon()
        case .success: CheckmarkIcon()
        case .warning: WarningIcon()
        case .error: ErrorIcon()
        }
    }
}

struct BannerModifier: ViewModifier {
    var configuration: SnackBarConfiguration
    @Binding var show: Bool

    @State private var task: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if show {
                    VStack(alignment: .leading) {
                        HStack(alignment: .top, spacing: 4) {
                            configuration.type.icon()

                            VStack(alignment: .leading, spacing: 2) {
                                Text(configuration.title)
                                    .font(.headline)
                                if let message = configuration.message {
                                    Text(message)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(4)
                                }
                            }
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(
                            Color(.darkGray)
                                .opacity(0.9)
                                .cornerRadius(4)
                                .shadow(radius: 8)
                        )
                        Spacer()
                    }
                    .padding()
                    .animation(.easeInOut(duration: 1.2), value: show)
                    .transition(AnyTransition.opacity)
                    .onTapGesture {
                        withAnimation {
                            self.show = false
                        }
                    }.onAppear {
                        if let duration = configuration.duration {
                            self.task = DispatchWorkItem {
                                withAnimation {
                                    self.show = false
                                }
                            }
                            // Auto dismiss and cancel the task if view disappear before the auto dismiss
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: self.task!)
                        }
                    }
                    .onDisappear {
                        self.task?.cancel()
                    }
                }
            }
    }
}

extension View {
    func snackBar(configuration: SnackBarConfiguration, show: Binding<Bool>) -> some View {
        self.modifier(BannerModifier(configuration: configuration, show: show))
    }
}

#Preview("info") {
    Text("Hello")
        .frame(width: 300, height: 300)
        .snackBar(configuration: SnackBarConfiguration(
            title: "This is the title",
            message: "The message can be a bit longer and should wrap.",
            type: .info
        ), show: .constant(true))
}

#Preview("success") {
    Text("Hello")
        .frame(width: 300, height: 300)
        .snackBar(configuration: SnackBarConfiguration(
            title: "This is the title",
            message: "The message can be a bit longer and should wrap.",
            type: .success
        ), show: .constant(true))
}

#Preview("warning") {
    Text("Hello")
        .frame(width: 300, height: 300)
        .snackBar(configuration: SnackBarConfiguration(
            title: "This is the title",
            message: "The message can be a bit longer and should wrap.",
            type: .warning
        ), show: .constant(true))
}

#Preview("error") {
    Text("Hello")
        .frame(width: 300, height: 300)
        .snackBar(configuration: SnackBarConfiguration(
            title: "This is the title",
            message: "The message can be a bit longer and should wrap.",
            type: .error
        ), show: .constant(true))
}


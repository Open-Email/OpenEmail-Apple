import SwiftUI

struct InfoIcon: View {
    var body: some View {
        Image(systemName: "info.circle.fill")
            .foregroundStyle(.white, .blue)
    }
}

struct CheckmarkIcon: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.white, .green)
    }
}

struct WarningIcon: View {
    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.white, .yellow)
    }
}

struct ErrorIcon: View {
    var body: some View {
        Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.white, .red)
    }
}

#Preview {
    HStack {
        InfoIcon()
        CheckmarkIcon()
        WarningIcon()
        ErrorIcon()
    }
    .padding()
}

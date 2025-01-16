import SwiftUI

struct PushButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundStyle(.white)
            .padding(.vertical, 4)
            .padding(.horizontal, 16)
            .frame(minWidth: 44, minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.accent)
            }
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

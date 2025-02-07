import SwiftUI

struct ProfileActionButton: View {
    let title: LocalizedStringKey
    let icon: ImageResource
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            VStack {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 24)
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(role == .destructive ? .themeRed : .white)
            .padding(.vertical, .Spacing.xSmall)
            .padding(.horizontal, .Spacing.default)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .cornerRadius(.CornerRadii.default)
            .colorScheme(.dark)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        ProfileActionButton(title: "Message", icon: .compose) {
        }

        ProfileActionButton(title: "Message", icon: .compose) {
        }

        ProfileActionButton(title: "Message", icon: .compose) {
        }

        ProfileActionButton(title: "Delete", icon: .trash, role: .destructive) {
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
    .background(.accent.gradient)
}

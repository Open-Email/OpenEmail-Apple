import SwiftUI

struct EmptyListView: View {
    let icon: ImageResource?
    let text: String

    var body: some View {
        HStack(spacing: .Spacing.small) {
            if let icon {
                ZStack {
                    Circle()
                        .fill(.themeIconBackground)
                        .frame(width: .Spacing.xLarge, height: .Spacing.xLarge)

                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 20)
                        .foregroundStyle(.themeSecondary)
                }
                .shadow(color: .themeShadow, radius: 4, y: 2)
            }

            Text(text)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, .Spacing.small)
        .frame(height: .Spacing.xxxLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: .CornerRadii.default)
                .fill(.themeViewBackground)
        }
        .padding(.Spacing.default)
    }
}

#Preview {
    EmptyListView(icon: .scopeContacts, text: "Empty List")
}

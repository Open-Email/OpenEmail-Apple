import SwiftUI

struct EmptyListView: View {
    let icon: ImageResource
    let text: String

    var body: some View {
        HStack(spacing: .Spacing.small) {
            ZStack {
                Circle()
                    .fill(.themeIconBackground)
                    .frame(width: 32, height: 32)
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 20)
                    .foregroundStyle(.themeSecondary)
            }
            .shadow(color: .themeShadow, radius: 4, y: 2)

            Text(text)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, .Spacing.small)
        .frame(height: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: .CornerRadii.default)
                .fill(.themeBackground)
        }
        .padding(.horizontal, .Spacing.default)
    }
}

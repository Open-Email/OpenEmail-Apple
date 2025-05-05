import SwiftUI

struct MessageTypeBadge: View {
    let scope: SidebarScope

    var body: some View {
        if let text = getLabel(scope: scope) {
            Text(text)
                .font(.callout)
            #if os(macOS)
                .fontWeight(.semibold)
            #else
                .font(.caption)
            #endif
                .padding(.horizontal, .Spacing.xSmall)
                .padding(.vertical, .Spacing.xxSmall)
                .background {
                    RoundedRectangle(cornerRadius: .CornerRadii.default)
                        .fill(.themeBadgeBackground)
                }
        } else {
            EmptyView()
        }
    }
}

#Preview {
    MessageTypeBadge(scope: .inbox)
}

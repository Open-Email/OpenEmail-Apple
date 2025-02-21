import SwiftUI

struct MessageTypeBadge: View {
    let scope: SidebarScope

    var body: some View {
        if let text {
            Text(text)
            #if os(macOS)
                .fontWeight(.semibold)
            #else
                .font(.caption)
            #endif
                .padding(.horizontal, .Spacing.xSmall)
                .padding(.vertical, .Spacing.xxSmall)
                .background {
                    RoundedRectangle(cornerRadius: .CornerRadii.small)
                        .fill(.themeBadgeBackground)
                }
        } else {
            EmptyView()
        }
    }

    private var text: String? {
        switch scope {
        case .broadcasts: "Broadcast"
        case .inbox: "Incoming"
        case .outbox: "Outgoing"
        case .drafts: "Draft"
        case .trash: nil
        case .contacts: nil
        }
    }
}

#Preview {
    MessageTypeBadge(scope: .inbox)
}

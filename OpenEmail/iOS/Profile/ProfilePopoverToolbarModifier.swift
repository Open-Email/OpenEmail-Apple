import SwiftUI

struct ProfilePopoverToolbarModifier: ViewModifier {
    let closeProfile: () -> Void

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .cancel) {
                        closeProfile()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(RoundToolbarButtonStyle())
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

extension View {
    func profilePopoverToolbar(closeProfile: @escaping () -> Void) -> some View {
        self.modifier(ProfilePopoverToolbarModifier(closeProfile: closeProfile))
    }
}

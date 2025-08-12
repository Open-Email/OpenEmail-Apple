import SwiftUI
import OpenEmailPersistence
import OpenEmailModel
import Logging
import OpenEmailCore

struct MultipleMessagesView: View {
    @Environment(NavigationState.self) private var navigationState

    @Injected(\.messagesStore) private var messagesStore
    @Injected(\.client) private var client
    
    var body: some View {
        VStack {
            Text(
                "\(navigationState.selectedMessageThreads.count) threads selected"
            )
            .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

#Preview {
    MultipleMessagesView()
        .frame(width: 500, height: 600)
        .environment(NavigationState())
}

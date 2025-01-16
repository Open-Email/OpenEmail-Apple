import SwiftUI
import Logging

struct LogView: View {
    @State private var messages: [String] = []

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text(messages.joined(separator: "\n"))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .textSelection(.enabled)
                .monospaced()
            }

            HStack(alignment: .center) {
                Spacer()
                Button("Clear log", systemImage: "trash") {
                    Log.clear()
                    messages = []
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .controlSize(.small)
                .padding(5)
                .padding(.trailing, 10)
            }
            .background()
        }
        .onReceive(Log.messagesPublisher) {
            messages.append($0)
        }
        .onAppear {
            messages = Log.messages
        }
    }
}

#Preview {
    LogView()
        .frame(width: 1000)
}

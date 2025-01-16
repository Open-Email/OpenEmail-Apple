import SwiftUI

struct AsyncButton<Label: View>: View {
    var actionOptions = Set<ActionOption>([.disableButton])
    var role: ButtonRole?
    var action: () async -> Void
    @ViewBuilder var label: () -> Label

    @State private var isDisabled = false
    @State private var showProgressView = false

    var body: some View {
        Button(
            role: role,
            action: {
                if actionOptions.contains(.disableButton) {
                    isDisabled = true
                }

                Task {
                    var progressViewTask: Task<Void, Error>?

                    if actionOptions.contains(.showProgressView) {
                        progressViewTask = Task {
                            try await Task.sleep(nanoseconds: 150_000_000)
                            showProgressView = true
                        }
                    }

                    await action()
                    progressViewTask?.cancel()

                    isDisabled = false
                    showProgressView = false
                }
            },
            label: {
                ZStack {
                    label().opacity(showProgressView ? 0 : 1)

                    if showProgressView {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        )
        .disabled(isDisabled)
    }
}

extension AsyncButton {
    enum ActionOption: CaseIterable {
        case disableButton
        case showProgressView
    }
}

extension AsyncButton where Label == Text {
    init(_ label: String,
         actionOptions: Set<ActionOption> = Set(ActionOption.allCases),
         role: ButtonRole? = nil,
         action: @escaping () async -> Void) {
        self.init(actionOptions: actionOptions, role: role, action: action) {
            Text(label)
        }
    }
}

extension AsyncButton where Label == Image {
    init(systemImageName: String,
         actionOptions: Set<ActionOption> = Set(ActionOption.allCases),
         role: ButtonRole? = nil,
         action: @escaping () async -> Void) {
        self.init(actionOptions: actionOptions, role: role, action: action) {
            Image(systemName: systemImageName)
        }
    }
}

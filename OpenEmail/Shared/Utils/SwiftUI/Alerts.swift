import Foundation
import SwiftUI

struct AlertConfiguration {
    let title: String
    let message: String?
}

struct AlertViewModifier: ViewModifier {
    @Binding var configuration: AlertConfiguration?
    var isShowingAlert: Binding<Bool> {
        Binding {
            configuration != nil
        } set: { _ in
            configuration = nil
        }
    }

    func body(content: Content) -> some View {
        content
            .alert(configuration?.title ?? "Something went wrong", isPresented: isShowingAlert) {
                // actions go here
            } message: {
                if let message = configuration?.message {
                    Text(message)
                }
            }
    }
}

extension View {
    func alert(_ configuration: Binding<AlertConfiguration?>) -> some View {
        self.modifier(AlertViewModifier(configuration: configuration))
    }
}

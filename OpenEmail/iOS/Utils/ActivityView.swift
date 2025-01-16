import SwiftUI
import UIKit

// From https://stackoverflow.com/a/68605378/379776
// Info: this might crash on iPad because sourceView has not been provided

struct ActivityView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    let data: [Any]

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let activityViewController = UIActivityViewController(
            activityItems: data,
            applicationActivities: nil
        )

        if isPresented && uiViewController.presentedViewController == nil {
            uiViewController.present(activityViewController, animated: true)
        }

        activityViewController.completionWithItemsHandler = { (_, _, _, _) in
            isPresented = false
        }
    }
}

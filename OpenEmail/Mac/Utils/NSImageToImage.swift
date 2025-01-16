import Foundation
import SwiftUI
import AppKit

extension NSImage {
    var swiftUIImage: Image { Image(nsImage: self) }
}

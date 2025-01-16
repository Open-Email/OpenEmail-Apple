import Foundation

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

#if canImport(UIKit)
public typealias OEImage = UIImage
#else
public typealias OEImage = NSImage
#endif

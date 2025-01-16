import Foundation

#if canImport(UIKit)
import UIKit

public extension UIImage {
    func resizeAndCrop(targetSize: CGSize) -> Data? {
        let scale = max(size.width / self.size.width, size.height / self.size.height)
        let newSize = CGSize(width: self.size.width * scale, height: self.size.height * scale)

        let origin = CGPoint(x: (size.width - newSize.width) / 2.0, y: (size.height - newSize.height) / 2.0)
        let rect = CGRect(origin: origin, size: newSize)

        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage?.pngData()
    }
}
#else
import AppKit

public extension NSImage {
    func resizeAndCrop(targetSize: CGSize) -> Data? {
        guard let sourceCGImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let context = CGContext(data: nil, width: Int(targetSize.width), height: Int(targetSize.height), bitsPerComponent: sourceCGImage.bitsPerComponent, bytesPerRow: 0, space: sourceCGImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: sourceCGImage.bitmapInfo.rawValue)

        context?.setFillColor(CGColor.white)
        context?.fill(CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))

        // Calculate the scaling and cropping
        let sourceSize = CGSize(width: sourceCGImage.width, height: sourceCGImage.height)
        let targetAspectRatio = targetSize.width / targetSize.height
        let sourceAspectRatio = sourceSize.width / sourceSize.height
        var scaleFactor: CGFloat
        if sourceAspectRatio > targetAspectRatio {
            scaleFactor = targetSize.height / sourceSize.height
        } else {
            scaleFactor = targetSize.width / sourceSize.width
        }
        let scaledWidth = sourceSize.width * scaleFactor
        let scaledHeight = sourceSize.height * scaleFactor
        let dx = (targetSize.width - scaledWidth) / 2
        let dy = (targetSize.height - scaledHeight) / 2

        // Drawing the image into the context, resizing and cropping it
        context?.draw(sourceCGImage, in: CGRect(x: dx, y: dy, width: scaledWidth, height: scaledHeight))

        guard let scaledCGImage = context?.makeImage() else { return nil }

        // Convert the CGImage to Data
        let bitmapRep = NSBitmapImageRep(cgImage: scaledCGImage)
        guard let imageData = bitmapRep.representation(using: .png, properties: [:]) else { return nil }

        return imageData
    }
}
#endif

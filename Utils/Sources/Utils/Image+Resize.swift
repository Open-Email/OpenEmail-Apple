import Foundation

#if canImport(UIKit)
import UIKit

public extension UIImage {
    func resizeAndCrop(targetSize: CGSize, quality: CGFloat = 0.8) -> Data? {
        let scale = max(targetSize.width / self.size.width, targetSize.height / self.size.height)
        let newSize = CGSize(width: self.size.width * scale, height: self.size.height * scale)

        let origin = CGPoint(x: (targetSize.width - newSize.width) / 2.0, y: (targetSize.height - newSize.height) / 2.0)
        let rect = CGRect(origin: origin, size: newSize)

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: targetSize))
        self.draw(in: rect)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage?.jpegData(compressionQuality: quality)
    }
}
#else
import AppKit

public extension NSImage {
    func resizeAndCrop(targetSize: CGSize, quality: CGFloat = 0.8) -> Data? {
        guard let sourceCGImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let context = CGContext(data: nil,
                                width: Int(targetSize.width),
                                height: Int(targetSize.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)

        guard let context = context else { return nil }

        context.setFillColor(CGColor.white)
        context.fill(CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))

        let sourceSize = CGSize(width: sourceCGImage.width, height: sourceCGImage.height)
        let targetAspectRatio = targetSize.width / targetSize.height
        let sourceAspectRatio = sourceSize.width / sourceSize.height

        let scaleFactor = sourceAspectRatio > targetAspectRatio ?
                          targetSize.height / sourceSize.height :
                          targetSize.width / sourceSize.width

        let scaledWidth = sourceSize.width * scaleFactor
        let scaledHeight = sourceSize.height * scaleFactor
        let dx = (targetSize.width - scaledWidth) / 2
        let dy = (targetSize.height - scaledHeight) / 2

        context.draw(sourceCGImage, in: CGRect(x: dx, y: dy, width: scaledWidth, height: scaledHeight))

        guard let scaledCGImage = context.makeImage() else { return nil }

        let bitmapRep = NSBitmapImageRep(cgImage: scaledCGImage)

        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}
#endif

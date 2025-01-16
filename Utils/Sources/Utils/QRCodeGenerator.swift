import Foundation
import CoreImage

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public final class QRCodeGenerator {
    public static func generateQRCode(from string: String) -> OEImage? {
        let data = string.data(using: String.Encoding.ascii)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 3, y: 3)

            if let output = filter.outputImage?.transformed(by: transform) {
#if canImport(UIKit)
                let context = CIContext()
                if let cgImage = context.createCGImage(output, from: output.extent) {
                    return UIImage(cgImage: cgImage)
                }
#else
                let rep = NSCIImageRep(ciImage: output)
                let nsImage = NSImage(size: rep.size)
                nsImage.addRepresentation(rep)
                return nsImage
#endif
            }
        }

        return nil
    }

}

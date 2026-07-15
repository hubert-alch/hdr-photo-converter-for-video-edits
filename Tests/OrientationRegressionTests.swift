import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
struct OrientationRegressionTests {
    static func main() throws {
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("portrait-orientation-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: fixture) }

        let image = try makeLandscapeImage()
        guard let destination = CGImageDestinationCreateWithURL(fixture as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            fatalError("Could not create the JPEG fixture.")
        }
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: 6] as CFDictionary)
        precondition(CGImageDestinationFinalize(destination), "Could not write the JPEG fixture.")

        let photo = try HDRPhotoInspector.inspect(fixture)
        precondition(photo.width == 2, "A right-oriented 4x2 photo must export at portrait width 2, got \(photo.width).")
        precondition(photo.height == 4, "A right-oriented 4x2 photo must export at portrait height 4, got \(photo.height).")
        precondition(photo.orientation == .right, "The EXIF orientation must be preserved for pixel rendering.")
        print("PASS: EXIF right orientation exports portrait dimensions.")
    }

    private static func makeLandscapeImage() throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 4,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NativeConversionError.decodeFailed
        }
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 2, y: 0, width: 2, height: 2))
        guard let image = context.makeImage() else {
            throw NativeConversionError.decodeFailed
        }
        return image
    }
}

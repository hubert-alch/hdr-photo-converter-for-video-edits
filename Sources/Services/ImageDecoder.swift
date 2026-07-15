import CoreImage
import CoreGraphics
import Foundation
import ImageIO

enum ImageDecoder {
    static func decodeRGBA(
        _ data: Data,
        width: Int,
        height: Int,
        orientation: CGImagePropertyOrientation
    ) throws -> [UInt8] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NativeConversionError.decodeFailed
        }

        var output = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let oriented = CIImage(cgImage: image).oriented(forExifOrientation: Int32(orientation.rawValue))
        let normalized = oriented.transformed(by: CGAffineTransform(
            translationX: -oriented.extent.origin.x,
            y: -oriented.extent.origin.y
        ))
        guard Int(normalized.extent.width) == width, Int(normalized.extent.height) == height else {
            throw NativeConversionError.decodeFailed
        }
        let context = CIContext(options: [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace,
        ])
        try output.withUnsafeMutableBytes { pointer in
            guard let baseAddress = pointer.baseAddress else {
                throw NativeConversionError.decodeFailed
            }
            context.render(
                normalized,
                toBitmap: baseAddress,
                rowBytes: width * 4,
                bounds: CGRect(x: 0, y: 0, width: width, height: height),
                format: .RGBA8,
                colorSpace: colorSpace
            )
        }
        return output
    }
}

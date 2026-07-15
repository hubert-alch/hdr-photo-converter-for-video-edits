import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

enum AppleGainMapComposer {
    private static let linearRec2020 = CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020)!

    static func fillPixelBuffer(
        _ buffer: CVPixelBuffer,
        source: URL,
        orientation: CGImagePropertyOrientation
    ) throws {
        guard let base = CIImage(contentsOf: source),
              let gainMap = CIImage(contentsOf: source, options: [.auxiliaryHDRGainMap: true]) else {
            throw NativeConversionError.decodeFailed
        }

        let hdrImage = base
            .applyingGainMap(gainMap)
            .oriented(forExifOrientation: Int32(orientation.rawValue))
        let context = CIContext(options: [
            .workingColorSpace: linearRec2020,
            .outputColorSpace: linearRec2020,
            .workingFormat: CIFormat.RGBAh,
        ])
        context.render(
            hdrImage,
            to: buffer,
            bounds: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer)),
            colorSpace: linearRec2020
        )
        HLGComposer.encodeLinearRec2020InPlace(buffer)
    }
}

import Foundation
import ImageIO
import UniformTypeIdentifiers

enum HDRPhotoInspector {
    private static let isoUltraHDRMarker = Data("urn:iso:std:iso:ts:21496:-1".utf8)

    static func inspect(_ url: URL) throws -> HDRPhotoInfo {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw NativeConversionError.badJPEG("ImageIO could not read this photo.")
        }
        // ImageIO may refine an Ultra HDR JPEG to a HEIF-like type after properties are read.
        let typeName = (CGImageSourceGetType(source) as String?) ?? url.pathExtension.lowercased()
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0

        if isJPEG(typeName: typeName), let isoInfo = try isoUltraHDRInfo(url, typeName: typeName, width: width, height: height) {
            return isoInfo
        }

        if CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeHDRGainMap) != nil {
            return HDRPhotoInfo(kind: .appleHDRGainMap, typeName: typeName, width: width, height: height, gainLog2: 0)
        }

        if isSupportedStill(typeName: typeName, url: url) {
            return HDRPhotoInfo(kind: .standardDynamicRange, typeName: typeName, width: width, height: height, gainLog2: 0)
        }
        return HDRPhotoInfo(kind: .unsupported, typeName: typeName, width: width, height: height, gainLog2: 0)
    }

    static func isCandidate(_ url: URL) -> Bool {
        let extensionName = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "heic", "heif"].contains(extensionName)
    }

    private static func isoUltraHDRInfo(_ url: URL, typeName: String, width: Int, height: Int) throws -> HDRPhotoInfo? {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.range(of: isoUltraHDRMarker) != nil,
              let parts = try? JPEGGainMapReader.embeddedJPEGs(data), parts.count >= 2 else {
            return nil
        }
        return HDRPhotoInfo(
            kind: .isoUltraHDRJPEG,
            typeName: typeName,
            width: width,
            height: height,
            gainLog2: JPEGGainMapReader.parseGainLog2(parts[1].data)
        )
    }

    private static func isJPEG(typeName: String) -> Bool {
        typeName == UTType.jpeg.identifier || typeName == "public.jpeg"
    }

    private static func isSupportedStill(typeName: String, url: URL) -> Bool {
        [UTType.jpeg.identifier, UTType.heic.identifier, "public.heif"].contains(typeName)
            || isCandidate(url)
    }
}

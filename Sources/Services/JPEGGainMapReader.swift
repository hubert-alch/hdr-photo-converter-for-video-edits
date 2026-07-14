import Foundation

struct JPEGPart {
    let data: Data
    let width: Int
    let height: Int
}

enum NativeConversionError: LocalizedError {
    case badJPEG(String)
    case decodeFailed
    case writerFailed
    case pixelBufferFailed
    case workerFailed(String)
    case cancelled(URL?)

    var errorDescription: String? {
        switch self {
        case .badJPEG(let message):
            return message
        case .decodeFailed:
            return "ImageIO could not decode the JPEG data."
        case .writerFailed:
            return "AVFoundation could not write the ProRes movie."
        case .pixelBufferFailed:
            return "Could not allocate a video pixel buffer."
        case .workerFailed(let message):
            return message
        case .cancelled:
            return "Conversion stopped."
        }
    }
}

enum JPEGGainMapReader {
    static func embeddedJPEGs(_ url: URL) throws -> [JPEGPart] {
        try embeddedJPEGs(Data(contentsOf: url, options: .mappedIfSafe))
    }

    static func embeddedJPEGs(_ data: Data) throws -> [JPEGPart] {
        var parts: [JPEGPart] = []
        var offset = 0
        while offset + 1 < data.count {
            guard let start = data[offset...].range(of: Data([0xff, 0xd8])) else { break }
            guard let end = data[start.lowerBound...].range(of: Data([0xff, 0xd9])) else {
                throw NativeConversionError.badJPEG("Missing JPEG end marker.")
            }
            let blob = data[start.lowerBound..<end.upperBound]
            let size = try jpegSize(blob)
            parts.append(JPEGPart(data: blob, width: size.width, height: size.height))
            offset = end.upperBound
        }
        if parts.count < 2 {
            throw NativeConversionError.badJPEG("No embedded gain-map JPEG.")
        }
        return parts
    }

    static func parseGainLog2(_ data: Data) -> Float {
        let marker = Data("urn:iso:std:iso:ts:21496:-1".utf8)
        guard let range = data.range(of: marker) else { return 2.0 }
        var rest = data[range.upperBound...]
        while rest.first == 0 { rest = rest.dropFirst() }
        guard rest.count >= 8 else { return 2.0 }
        let bits = rest.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        let value = Double(bitPattern: bits)
        return value > 0 && value <= 8 ? Float(value) : 2.0
    }

    private static func jpegSize(_ data: Data) throws -> (width: Int, height: Int) {
        let bytes = [UInt8](data)
        var pos = 2
        while pos < bytes.count {
            if bytes[pos] != 0xff { break }
            while pos < bytes.count, bytes[pos] == 0xff { pos += 1 }
            let marker = bytes[pos]
            pos += 1
            if marker == 0xd9 || marker == 0xda { break }
            let length = Int(bytes[pos]) << 8 | Int(bytes[pos + 1])
            if marker == 0xc0 || marker == 0xc1 || marker == 0xc2 {
                let height = Int(bytes[pos + 3]) << 8 | Int(bytes[pos + 4])
                let width = Int(bytes[pos + 5]) << 8 | Int(bytes[pos + 6])
                return (width, height)
            }
            pos += length
        }
        throw NativeConversionError.badJPEG("Missing JPEG dimensions.")
    }
}

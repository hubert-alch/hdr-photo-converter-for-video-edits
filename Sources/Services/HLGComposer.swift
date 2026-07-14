import CoreVideo
import Foundation

enum HLGComposer {
    static func fillPixelBuffer(
        _ buffer: CVPixelBuffer,
        base: [UInt8],
        gain: [UInt8],
        width: Int,
        height: Int,
        gainLog2: Float
    ) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let dest = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt16.self)
        let maxGain = pow(Float(2.0), gainLog2)
        for index in 0..<(width * height) {
            writePixel(index, dest: dest, base: base, gain: gain, gainLog2: gainLog2, maxGain: maxGain)
        }
    }

    static func encodeLinearRec2020InPlace(_ buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let values = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt16.self)
        let pixelCount = CVPixelBufferGetWidth(buffer) * CVPixelBufferGetHeight(buffer)
        for index in 0..<pixelCount {
            let offset = index * 4
            values[offset] = Float16(hlg(clamp(Float(Float16(bitPattern: values[offset]))))).bitPattern
            values[offset + 1] = Float16(hlg(clamp(Float(Float16(bitPattern: values[offset + 1]))))).bitPattern
            values[offset + 2] = Float16(hlg(clamp(Float(Float16(bitPattern: values[offset + 2]))))).bitPattern
            values[offset + 3] = Float16(1.0).bitPattern
        }
    }

    private static func writePixel(
        _ index: Int,
        dest: UnsafeMutablePointer<UInt16>,
        base: [UInt8],
        gain: [UInt8],
        gainLog2: Float,
        maxGain: Float
    ) {
        let source = index * 4
        let boost = pow(Float(2.0), gainLog2 * Float(gain[source]) / 255.0) / maxGain
        let red = srgbToLinear(Float(base[source]) / 255.0) * boost
        let green = srgbToLinear(Float(base[source + 1]) / 255.0) * boost
        let blue = srgbToLinear(Float(base[source + 2]) / 255.0) * boost
        let recRed = clamp(0.6274040 * red + 0.3292820 * green + 0.0433136 * blue)
        let recGreen = clamp(0.0690970 * red + 0.9195400 * green + 0.0113612 * blue)
        let recBlue = clamp(0.0163916 * red + 0.0880132 * green + 0.8955950 * blue)
        let target = index * 4
        dest[target] = Float16(hlg(recRed)).bitPattern
        dest[target + 1] = Float16(hlg(recGreen)).bitPattern
        dest[target + 2] = Float16(hlg(recBlue)).bitPattern
        dest[target + 3] = Float16(1.0).bitPattern
    }

    private static func srgbToLinear(_ value: Float) -> Float {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func hlg(_ value: Float) -> Float {
        if value <= 1.0 / 12.0 {
            return sqrt(3.0 * value)
        }
        return 0.17883277 * log(12.0 * value - 0.28466892) + 0.55991073
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

import AVFoundation
import CoreVideo
import Foundation
import VideoToolbox

final class ProResExporter {
    func export(source: URL, output: URL, duration: Double, exportFormat: ExportFormat) throws -> Clip {
        let photo = try HDRPhotoInspector.inspect(source)
        guard photo.kind.isConvertible else {
            throw NativeConversionError.badJPEG("\(photo.kind.title): no HDR gain map was found.")
        }
        switch photo.kind {
        case .isoUltraHDRJPEG:
            return try exportISOUltraHDR(source: source, output: output, duration: duration, photo: photo, exportFormat: exportFormat)
        case .appleHDRGainMap:
            return try exportAppleHDR(source: source, output: output, duration: duration, photo: photo, exportFormat: exportFormat)
        default:
            throw NativeConversionError.badJPEG("This photo is not a supported HDR gain-map image.")
        }
    }

    private func exportISOUltraHDR(
        source: URL,
        output: URL,
        duration: Double,
        photo: HDRPhotoInfo,
        exportFormat: ExportFormat
    ) throws -> Clip {
        let parts = try JPEGGainMapReader.embeddedJPEGs(source)
        let width = photo.width
        let height = photo.height
        let base = try ImageDecoder.decodeRGBA(parts[0].data, width: width, height: height)
        let gain = try ImageDecoder.decodeRGBA(parts[1].data, width: width, height: height)
        return try writeMovie(source: source, output: output, duration: duration, photo: photo, exportFormat: exportFormat) { buffer in
            HLGComposer.fillPixelBuffer(buffer, base: base, gain: gain, width: width, height: height, gainLog2: photo.gainLog2)
        }
    }

    private func exportAppleHDR(
        source: URL,
        output: URL,
        duration: Double,
        photo: HDRPhotoInfo,
        exportFormat: ExportFormat
    ) throws -> Clip {
        try writeMovie(source: source, output: output, duration: duration, photo: photo, exportFormat: exportFormat) { buffer in
            try AppleGainMapComposer.fillPixelBuffer(buffer, source: source)
        }
    }

    private func writeMovie(
        source: URL,
        output: URL,
        duration: Double,
        photo: HDRPhotoInfo,
        exportFormat: ExportFormat,
        compose: (CVPixelBuffer) throws -> Void
    ) throws -> Clip {
        let width = photo.width
        let height = photo.height
        try? FileManager.default.removeItem(at: output)
        let writer = try configuredWriter(output: output, width: width, height: height)
        let input = configuredInput(width: width, height: height, exportFormat: exportFormat)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: pixelAttributes(width: width, height: height))
        writer.add(input)
        guard writer.startWriting() else { throw NativeConversionError.writerFailed }
        writer.startSession(atSourceTime: .zero)
        guard let buffer = makeBuffer(adaptor: adaptor) else { throw NativeConversionError.pixelBufferFailed }
        try compose(buffer)
        let frameCount = Int(duration * 25)
        try append(buffer: buffer, input: input, adaptor: adaptor, frameCount: frameCount)
        try finish(writer: writer, input: input)
        return Clip(source: source, movie: output, width: width, height: height, durationFrames: frameCount, gainLog2: photo.gainLog2)
    }

    private func configuredWriter(output: URL, width: Int, height: Int) throws -> AVAssetWriter {
        let writer = try AVAssetWriter(outputURL: output, fileType: .mov)
        return writer
    }

    private func configuredInput(width: Int, height: Int, exportFormat: ExportFormat) -> AVAssetWriterInput {
        var settings: [String: Any] = [
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
            ],
        ]
        switch exportFormat {
        case .hevcHLG:
            settings[AVVideoCodecKey] = AVVideoCodecType.hevc
            settings[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: 40_000_000,
                AVVideoExpectedSourceFrameRateKey: 25,
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel,
            ]
        case .proRes4444HLG:
            settings[AVVideoCodecKey] = AVVideoCodecType.proRes4444
        }
        return AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    }

    private func pixelAttributes(width: Int, height: Int) -> [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
    }

    private func makeBuffer(adaptor: AVAssetWriterInputPixelBufferAdaptor) -> CVPixelBuffer? {
        guard let pool = adaptor.pixelBufferPool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        return buffer
    }

    private func append(
        buffer: CVPixelBuffer,
        input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        frameCount: Int
    ) throws {
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
            let time = CMTime(value: CMTimeValue(frame), timescale: 25)
            if !adaptor.append(buffer, withPresentationTime: time) {
                throw NativeConversionError.writerFailed
            }
        }
    }

    private func finish(writer: AVAssetWriter, input: AVAssetWriterInput) throws {
        let group = DispatchGroup()
        group.enter()
        input.markAsFinished()
        writer.finishWriting { group.leave() }
        group.wait()
        if writer.status != .completed {
            throw writer.error ?? NativeConversionError.writerFailed
        }
    }
}

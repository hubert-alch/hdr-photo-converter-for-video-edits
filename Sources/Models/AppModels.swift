import Foundation

enum HDRPhotoKind: Hashable {
    case isoUltraHDRJPEG
    case appleHDRGainMap
    case standardDynamicRange
    case unsupported
    case folder

    var title: String {
        switch self {
        case .isoUltraHDRJPEG: return "ISO Ultra HDR JPEG"
        case .appleHDRGainMap: return "Apple HDR Gain Map"
        case .standardDynamicRange: return "Standard SDR"
        case .unsupported: return "Unsupported"
        case .folder: return "Folder"
        }
    }

    var isConvertible: Bool {
        self == .isoUltraHDRJPEG || self == .appleHDRGainMap
    }
}

struct HDRPhotoInfo: Hashable {
    let kind: HDRPhotoKind
    let typeName: String
    let width: Int
    let height: Int
    let gainLog2: Float

    var dimensions: String { "\(width) x \(height)" }
}

struct SourceItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let photoInfo: HDRPhotoInfo?

    init(url: URL) {
        self.url = url
        if Self.isDirectory(url) {
            self.photoInfo = nil
        } else {
            self.photoInfo = try? HDRPhotoInspector.inspect(url)
        }
    }

    var displayName: String { url.lastPathComponent }
    var detail: String { url.deletingLastPathComponent().path }
    var kind: HDRPhotoKind { isFolder ? .folder : photoInfo?.kind ?? .unsupported }
    var formatDetail: String? {
        guard let photoInfo else { return nil }
        return "\(photoInfo.kind.title)  ·  \(photoInfo.dimensions)"
    }
    var isFolder: Bool {
        Self.isDirectory(url)
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case hevcHLG = "hevc-hlg"
    case proRes4444HLG = "prores-4444-hlg"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hevcHLG:
            return "HEVC HLG (Compact)"
        case .proRes4444HLG:
            return "ProRes 4444 HLG"
        }
    }

    var detail: String {
        switch self {
        case .hevcHLG:
            return "10-bit HLG at 40 Mb/s. Best for normal editing and storage."
        case .proRes4444HLG:
            return "Large intermediate files for finishing workflows."
        }
    }

    var filenameSuffix: String {
        switch self {
        case .hevcHLG:
            return "HLG_HEVC"
        case .proRes4444HLG:
            return "HLG_ProRes4444"
        }
    }
}

struct ConversionRequest {
    let sources: [URL]
    let outputDirectory: URL
    let duration: Double
    let recursive: Bool
    let createProjectTimeline: Bool
    let openFinalCut: Bool
    let exportFormat: ExportFormat

    init(
        sources: [URL],
        outputDirectory: URL,
        duration: Double,
        recursive: Bool,
        createProjectTimeline: Bool,
        openFinalCut: Bool,
        exportFormat: ExportFormat = .hevcHLG
    ) {
        self.sources = sources
        self.outputDirectory = outputDirectory
        self.duration = duration
        self.recursive = recursive
        self.createProjectTimeline = createProjectTimeline
        self.openFinalCut = openFinalCut
        self.exportFormat = exportFormat
    }
}

struct Clip {
    let source: URL
    let movie: URL
    let width: Int
    let height: Int
    let durationFrames: Int
    let gainLog2: Float
}

enum ConversionStatus: Equatable {
    case idle
    case running
    case succeeded(URL)
    case stopped(URL?)
    case failed(String)

    var label: String {
        switch self {
        case .idle:
            return "Ready"
        case .running:
            return "Converting"
        case .succeeded:
            return "Complete"
        case .stopped:
            return "Stopped"
        case .failed:
            return "Failed"
        }
    }
}

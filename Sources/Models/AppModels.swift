import Foundation
import ImageIO

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
    let orientation: CGImagePropertyOrientation
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

enum TimelineImportTarget: String, CaseIterable, Identifiable {
    case finalCutPro = "final-cut-pro"
    case davinciResolve = "davinci-resolve"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .finalCutPro:
            return "Final Cut Pro"
        case .davinciResolve:
            return "DaVinci Resolve"
        }
    }

    var detail: String {
        switch self {
        case .finalCutPro:
            return "Creates an FCPXML package for Final Cut Pro import."
        case .davinciResolve:
            return "Creates a Resolve-friendly FCPXML timeline; drag the movies directly if no timeline is needed."
        }
    }

    var xmlFileName: String {
        switch self {
        case .finalCutPro:
            return "HDR_Photo_Batch_HLG.fcpxml"
        case .davinciResolve:
            return "HDR_Photo_Batch_HLG_DaVinci_Resolve.fcpxml"
        }
    }

    var eventName: String {
        switch self {
        case .finalCutPro:
            return "HDR Photo Batch"
        case .davinciResolve:
            return "HDR Photo Batch Resolve"
        }
    }

    var projectName: String {
        switch self {
        case .finalCutPro:
            return "HDR Photo Batch HLG"
        case .davinciResolve:
            return "HDR Photo Batch HLG Resolve"
        }
    }

    func modeDetail(createProject: Bool) -> String {
        switch (self, createProject) {
        case (.finalCutPro, true):
            return "The FCPXML creates a new timeline with all converted clips arranged in sequence."
        case (.finalCutPro, false):
            return "The FCPXML imports converted clips into an event. Drag them into any existing project."
        case (.davinciResolve, true):
            return "Import the FCPXML with File > Import Timeline to recreate the clip order in Resolve."
        case (.davinciResolve, false):
            return "Resolve can import the converted movies directly. Use timeline mode when you want XML-based sequence import."
        }
    }
}

struct ConversionRequest {
    let sources: [URL]
    let outputDirectory: URL
    let duration: Double
    let recursive: Bool
    let createProjectTimeline: Bool
    let openGeneratedXML: Bool
    let exportFormat: ExportFormat
    let timelineTarget: TimelineImportTarget

    init(
        sources: [URL],
        outputDirectory: URL,
        duration: Double,
        recursive: Bool,
        createProjectTimeline: Bool,
        openGeneratedXML: Bool,
        exportFormat: ExportFormat = .hevcHLG,
        timelineTarget: TimelineImportTarget = .finalCutPro
    ) {
        self.sources = sources
        self.outputDirectory = outputDirectory
        self.duration = duration
        self.recursive = recursive
        self.createProjectTimeline = createProjectTimeline
        self.openGeneratedXML = openGeneratedXML
        self.exportFormat = exportFormat
        self.timelineTarget = timelineTarget
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
    case succeeded(URL, TimelineImportTarget)
    case stopped(URL?, TimelineImportTarget?)
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

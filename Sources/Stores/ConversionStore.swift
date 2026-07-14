import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ConversionStore: ObservableObject {
    @Published var sources: [SourceItem] = []
    @Published var outputDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Movies/HDR Photo Converter")
    @Published var durationText = "4"
    @Published var exportFormat: ExportFormat = .hevcHLG
    @Published var timelineTarget: TimelineImportTarget = .finalCutPro
    @Published var recursive = false
    @Published var createProjectTimeline = false
    @Published var shouldOpenGeneratedXML = false
    @Published var logs: [String] = ["Add ISO Ultra HDR JPEG or Apple HDR HEIC photos, then convert them to compact HLG HEVC movies."]
    @Published var status: ConversionStatus = .idle

    private let service = BatchConversionService()

    var canConvert: Bool {
        !sources.isEmpty && durationValue != nil && status != .running
    }

    var durationValue: Double? {
        guard let value = Double(durationText), value > 0.1 else {
            return nil
        }
        return value
    }

    func add(urls: [URL]) {
        let existing = Set(sources.map(\.url))
        let newItems = urls
            .filter { !existing.contains($0) }
            .map(SourceItem.init(url:))
        sources.append(contentsOf: newItems)
    }

    func remove(_ item: SourceItem) {
        sources.removeAll { $0.id == item.id }
    }

    func clear() {
        sources.removeAll()
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.jpeg, .heic, UTType(filenameExtension: "heif")!]
        if panel.runModal() == .OK {
            add(urls: panel.urls)
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            add(urls: [url])
        }
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputDirectory
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
        }
    }

    func addDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = droppedURL(from: item) else { return }
                Task { @MainActor in self.add(urls: [url]) }
            }
        }
        return true
    }

    func startConversion() {
        guard let duration = durationValue else {
            append("Duration must be a number greater than 0.1 seconds.")
            return
        }
        let request = ConversionRequest(
            sources: sources.map(\.url),
            outputDirectory: outputDirectory,
            duration: duration,
            recursive: recursive,
            createProjectTimeline: createProjectTimeline,
            openGeneratedXML: shouldOpenGeneratedXML,
            exportFormat: exportFormat,
            timelineTarget: timelineTarget
        )
        status = .running
        append("Starting conversion...")
        Task.detached { [service] in
            do {
                let xml = try service.convert(request: request) { line in
                    Task { @MainActor in self.append(line) }
                }
                Task { @MainActor in self.status = .succeeded(xml, request.timelineTarget) }
            } catch NativeConversionError.cancelled(let xml) {
                Task { @MainActor in self.status = .stopped(xml, request.timelineTarget) }
            } catch {
                Task { @MainActor in self.status = .failed(error.localizedDescription) }
            }
        }
    }

    func stopConversion() {
        guard status == .running else { return }
        append("Stopping conversion...")
        service.cancel()
    }

    func openOutputDirectory() {
        NSWorkspace.shared.open(outputDirectory)
    }

    func openGeneratedXML() {
        switch status {
        case .succeeded(let xml, _):
            NSWorkspace.shared.open(xml)
        case .stopped(let xml?, _):
            NSWorkspace.shared.open(xml)
        default:
            break
        }
    }

    private func append(_ line: String) {
        logs.append(line)
    }
}

private func droppedURL(from item: NSSecureCoding?) -> URL? {
    if let url = item as? URL {
        return url
    }
    if let data = item as? Data {
        return URL(dataRepresentation: data, relativeTo: nil)
    }
    return nil
}

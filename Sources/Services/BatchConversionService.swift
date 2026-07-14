import AppKit
import Foundation

final class BatchConversionService {
    private let exporter = ProResExporter()
    private let workerURL: URL?
    private let cancellation = ConversionCancellation()

    init(workerURL: URL? = ConversionWorkerLocator.locate()) {
        self.workerURL = workerURL
    }

    func cancel() {
        cancellation.requestStop()
    }

    func convert(request: ConversionRequest, onLine: @escaping (String) -> Void) throws -> URL {
        cancellation.begin()
        defer { cancellation.finish() }
        let sources = collectSources(request: request)
        if sources.isEmpty {
            throw NativeConversionError.badJPEG("No JPEG files were selected.")
        }

        let moviesDir = request.outputDirectory.appendingPathComponent("movies", isDirectory: true)
        try FileManager.default.createDirectory(at: moviesDir, withIntermediateDirectories: true)

        var clips: [Clip] = []
        var skipped: [String] = []
        var wasCancelled = false
        for source in sources {
            if cancellation.isRequested {
                wasCancelled = true
                break
            }
            var cancelledDuringPhoto = false
            autoreleasepool {
                do {
                    let photo = try HDRPhotoInspector.inspect(source)
                    guard photo.kind.isConvertible else {
                        throw NativeConversionError.badJPEG("\(photo.kind.title): no HDR gain map was found.")
                    }
                    onLine("Converting \(source.lastPathComponent) [\(photo.kind.title)]")
                    let output = moviesDir.appendingPathComponent("\(safeName(source))_\(request.exportFormat.filenameSuffix).mov")
                    let clip = try convertOne(
                        source: source,
                        output: output,
                        duration: request.duration,
                        photo: photo,
                        exportFormat: request.exportFormat
                    )
                    clips.append(clip)
                } catch {
                    if cancellation.isRequested {
                        try? FileManager.default.removeItem(at: outputURL(for: source, request: request, moviesDirectory: moviesDir))
                        cancelledDuringPhoto = true
                        return
                    }
                    skipped.append("\(source.path): \(error.localizedDescription)")
                    onLine("Skipped \(source.lastPathComponent): \(error.localizedDescription)")
                }
            }
            if cancelledDuringPhoto {
                wasCancelled = true
                break
            }
        }

        if clips.isEmpty {
            if wasCancelled || cancellation.isRequested {
                throw NativeConversionError.cancelled(nil)
            }
            throw NativeConversionError.badJPEG("No convertible HDR gain-map photos found.")
        }
        let xml = request.outputDirectory.appendingPathComponent(request.timelineTarget.xmlFileName)
        try FCPXMLWriter.write(
            clips: clips,
            to: xml,
            createProject: request.createProjectTimeline,
            target: request.timelineTarget
        )
        let stopped = wasCancelled || cancellation.isRequested
        try writeReport(clips: clips, skipped: skipped, stopped: stopped, outputDirectory: request.outputDirectory)
        onLine("Wrote \(xml.path)")
        if stopped {
            onLine("Stopped after \(clips.count) completed file(s).")
            throw NativeConversionError.cancelled(xml)
        }
        onLine("Converted \(clips.count) file(s), skipped \(skipped.count).")
        if request.openGeneratedXML {
            NSWorkspace.shared.open(xml)
        }
        return xml
    }

    private func collectSources(request: ConversionRequest) -> [URL] {
        var result: Set<URL> = []
        for source in request.sources {
            var isDirectory = ObjCBool(false)
            if FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue {
                result.formUnion(jpegs(in: source, recursive: request.recursive))
            } else if HDRPhotoInspector.isCandidate(source) {
                result.insert(source)
            }
        }
        return result.sorted { $0.path < $1.path }
    }

    private func jpegs(in directory: URL, recursive: Bool) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: recursive ? [] : [.skipsSubdirectoryDescendants]
        ) else {
            return []
        }
        return enumerator.compactMap { item in
            guard let url = item as? URL, HDRPhotoInspector.isCandidate(url) else { return nil }
            return url
        }
    }

    private func safeName(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: " ", with: "_")
    }

    private func outputURL(for source: URL, request: ConversionRequest, moviesDirectory: URL) -> URL {
        moviesDirectory.appendingPathComponent("\(safeName(source))_\(request.exportFormat.filenameSuffix).mov")
    }

    private func writeReport(clips: [Clip], skipped: [String], stopped: Bool, outputDirectory: URL) throws {
        let report: [String: Any] = [
            "converted": clips.map { $0.movie.path },
            "skipped": skipped,
            "stopped": stopped,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: report, format: .xml, options: 0)
        try data.write(to: outputDirectory.appendingPathComponent("conversion_report.plist"))
    }

    private func convertOne(
        source: URL,
        output: URL,
        duration: Double,
        photo: HDRPhotoInfo,
        exportFormat: ExportFormat
    ) throws -> Clip {
        guard let workerURL else {
            return try exporter.export(source: source, output: output, duration: duration, exportFormat: exportFormat)
        }

        try runWorker(workerURL: workerURL, source: source, output: output, duration: duration, exportFormat: exportFormat)
        return Clip(
            source: source,
            movie: output,
            width: photo.width,
            height: photo.height,
            durationFrames: Int(duration * 25),
            gainLog2: photo.gainLog2
        )
    }

    private func runWorker(
        workerURL: URL,
        source: URL,
        output: URL,
        duration: Double,
        exportFormat: ExportFormat
    ) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = workerURL
        process.arguments = [source.path, output.path, String(duration), exportFormat.rawValue]
        process.standardError = errorPipe
        try process.run()
        cancellation.register(process)
        defer { cancellation.clear(process) }
        process.waitUntilExit()
        if cancellation.isRequested {
            throw NativeConversionError.cancelled(nil)
        }
        guard process.terminationStatus == 0 else {
            let message = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NativeConversionError.workerFailed(message?.isEmpty == false ? message! : "The converter worker failed.")
        }
    }
}

private final class ConversionCancellation {
    private let lock = NSLock()
    private var requested = false
    private var worker: Process?

    var isRequested: Bool {
        lock.lock()
        defer { lock.unlock() }
        return requested
    }

    func begin() {
        lock.lock()
        requested = false
        worker = nil
        lock.unlock()
    }

    func finish() {
        lock.lock()
        worker = nil
        lock.unlock()
    }

    func requestStop() {
        lock.lock()
        requested = true
        let activeWorker = worker
        lock.unlock()
        activeWorker?.terminate()
    }

    func register(_ process: Process) {
        lock.lock()
        worker = process
        let shouldStop = requested
        lock.unlock()
        if shouldStop {
            process.terminate()
        }
    }

    func clear(_ process: Process) {
        lock.lock()
        if worker === process {
            worker = nil
        }
        lock.unlock()
    }
}

private enum ConversionWorkerLocator {
    static func locate() -> URL? {
        if let path = ProcessInfo.processInfo.environment["ULTRAHDR_WORKER_PATH"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return Bundle.main.url(forAuxiliaryExecutable: "HDR Photo Converter for Video Editors Converter")
    }
}

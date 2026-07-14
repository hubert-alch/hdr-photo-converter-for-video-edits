import Foundation

@main
struct BatchRoutingIntegrationTests {
    static func main() throws {
        guard CommandLine.arguments.count == 5 else {
            fatalError("Usage: BatchRoutingIntegrationTests <worker> <iso-jpeg> <apple-hdr-heic> <sdr-heic>")
        }
        let worker = URL(fileURLWithPath: CommandLine.arguments[1])
        let sources = CommandLine.arguments[2...4].map(URL.init(fileURLWithPath:))
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }

        let request = ConversionRequest(
            sources: sources,
            outputDirectory: output,
            duration: 0.2,
            recursive: false,
            createProjectTimeline: false,
            openGeneratedXML: false
        )
        let xml = try BatchConversionService(workerURL: worker).convert(request: request) { _ in }
        let xmlText = try String(contentsOf: xml, encoding: .utf8)
        precondition(xmlText.contains("IMG_20260711_164523_116_HLG_HEVC.mov"))
        precondition(xmlText.contains("IMG_4170_HLG_HEVC.mov"))
        precondition(!xmlText.contains("Image Playground 2026-07-14 at 9.05.46 下午_HLG_HEVC.mov"))

        let reportURL = output.appendingPathComponent("conversion_report.plist")
        let report = try PropertyListSerialization.propertyList(from: Data(contentsOf: reportURL), format: nil) as! [String: Any]
        precondition((report["converted"] as? [String])?.count == 2)
        precondition((report["skipped"] as? [String])?.count == 1)

        try verifyCancellation(source: sources[0], outputDirectory: output)
        print("PASS: ISO Ultra HDR JPEG and Apple HDR HEIC converted; SDR HEIC skipped.")
    }

    private static func verifyCancellation(source: URL, outputDirectory: URL) throws {
        let worker = outputDirectory.appendingPathComponent("slow-worker.sh")
        try Data("#!/bin/zsh\nsleep 30\n".utf8).write(to: worker)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: worker.path)

        let service = BatchConversionService(workerURL: worker)
        let request = ConversionRequest(
            sources: [source],
            outputDirectory: outputDirectory.appendingPathComponent("cancelled"),
            duration: 4,
            recursive: false,
            createProjectTimeline: false,
            openGeneratedXML: false
        )
        let conversionStarted = DispatchSemaphore(value: 0)
        let conversionFinished = DispatchSemaphore(value: 0)
        let outcomeLock = NSLock()
        var wasCancelled = false

        DispatchQueue.global().async {
            defer { conversionFinished.signal() }
            do {
                _ = try service.convert(request: request) { line in
                    if line.hasPrefix("Converting") {
                        conversionStarted.signal()
                    }
                }
            } catch NativeConversionError.cancelled {
                outcomeLock.lock()
                wasCancelled = true
                outcomeLock.unlock()
            } catch {
                return
            }
        }

        precondition(conversionStarted.wait(timeout: .now() + 2) == .success)
        service.cancel()
        precondition(conversionFinished.wait(timeout: .now() + 2) == .success)
        outcomeLock.lock()
        let cancelled = wasCancelled
        outcomeLock.unlock()
        precondition(cancelled)
    }
}

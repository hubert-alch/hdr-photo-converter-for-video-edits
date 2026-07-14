import Darwin
import Foundation

@main
struct ConversionWorkerMain {
    static func main() {
        do {
            guard CommandLine.arguments.count == 5,
                  let duration = Double(CommandLine.arguments[3]), duration > 0 else {
                throw NativeConversionError.workerFailed("Usage: converter <source.jpg> <output.mov> <duration> <format>")
            }
            let source = URL(fileURLWithPath: CommandLine.arguments[1])
            let output = URL(fileURLWithPath: CommandLine.arguments[2])
            guard let exportFormat = ExportFormat(rawValue: CommandLine.arguments[4]) else {
                throw NativeConversionError.workerFailed("Unsupported output format.")
            }
            _ = try ProResExporter().export(source: source, output: output, duration: duration, exportFormat: exportFormat)
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}

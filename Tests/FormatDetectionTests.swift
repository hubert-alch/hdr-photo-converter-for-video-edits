import Foundation

@main
struct FormatDetectionTests {
    static func main() throws {
        let cases = stride(from: 1, to: CommandLine.arguments.count, by: 2).map {
            (URL(fileURLWithPath: CommandLine.arguments[$0]), CommandLine.arguments[$0 + 1])
        }
        guard !cases.isEmpty else {
            fatalError("Usage: FormatDetectionTests <photo> <expected-kind> [...]")
        }

        for (url, expected) in cases {
            let actual = try HDRPhotoInspector.inspect(url)
            precondition(actual.kind.title == expected, "\(url.lastPathComponent): expected \(expected), got \(actual.kind.title)")
            print("PASS \(url.lastPathComponent): \(actual.kind.title) \(actual.dimensions)")
        }
    }
}

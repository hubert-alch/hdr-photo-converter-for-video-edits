import Foundation

enum FCPXMLWriter {
    static func write(clips: [Clip], to url: URL, createProject: Bool, target: TimelineImportTarget) throws {
        var resources: [String] = []
        var eventItems: [String] = []
        var offset = 0
        for (index, clip) in clips.enumerated() {
            let format = "f\(index + 1)"
            let asset = "a\(index + 1)"
            let duration = "\(clip.durationFrames)/25s"
            let name = xmlEscape(clip.movie.deletingPathExtension().lastPathComponent)
            resources.append(formatElement(id: format, clip: clip))
            resources.append(assetElement(id: asset, name: name, clip: clip, duration: duration))
            eventItems.append(assetClipElement(asset: asset, name: name, offset: offset, duration: duration))
            offset += clip.durationFrames
        }
        let body = createProject
            ? projectBody(items: eventItems, totalFrames: offset, target: target)
            : eventItems.joined(separator: "\n")
        let xml = document(resources: resources.joined(separator: "\n"), body: body, target: target)
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func formatElement(id: String, clip: Clip) -> String {
        """
            <format id="\(id)" name="FFVideoFormat\(clip.height)p25" frameDuration="1/25s" width="\(clip.width)" height="\(clip.height)" colorSpace="9-18-9 (Rec. 2020 HLG)"/>
        """
    }

    private static func assetElement(id: String, name: String, clip: Clip, duration: String) -> String {
        """
            <asset id="\(id)" name="\(name)" start="0s" duration="\(duration)" hasVideo="1" format="f\(id.dropFirst())">
              <media-rep kind="original-media" src="\(clip.movie.absoluteString)"/>
            </asset>
        """
    }

    private static func assetClipElement(asset: String, name: String, offset: Int, duration: String) -> String {
        """
              <asset-clip name="\(name)" ref="\(asset)" offset="\(offset)/25s" duration="\(duration)" start="0s"/>
        """
    }

    private static func projectBody(items: [String], totalFrames: Int, target: TimelineImportTarget) -> String {
        """
              <project name="\(xmlEscape(target.projectName))">
                <sequence duration="\(totalFrames)/25s" tcStart="0s" tcFormat="NDF" audioLayout="stereo" audioRate="48k">
                  <spine>
        \(items.joined(separator: "\n"))
                  </spine>
                </sequence>
              </project>
        """
    }

    private static func document(resources: String, body: String, target: TimelineImportTarget) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="1.10">
          <resources>
        \(resources)
          </resources>
          <library colorProcessing="wide-hdr">
            <event name="\(xmlEscape(target.eventName))">
        \(body)
            </event>
          </library>
        </fcpxml>
        """
    }

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

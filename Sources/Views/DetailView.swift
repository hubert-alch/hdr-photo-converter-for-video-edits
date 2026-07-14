import SwiftUI

struct DetailView: View {
    @ObservedObject var store: ConversionStore

    var body: some View {
        VStack(spacing: 14) {
            SettingsPanel(store: store)
            ConversionActions(store: store)
            LogPanel(logs: store.logs)
        }
        .padding(18)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
    }
}

struct SettingsPanel: View {
    @ObservedObject var store: ConversionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Output")
                .font(.headline)

            HStack(spacing: 10) {
                Image(systemName: "externaldrive")
                    .foregroundStyle(.secondary)
                Text(store.outputDirectory.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Choose...") {
                    store.chooseOutputDirectory()
                }
            }
            .padding(10)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    SettingField(title: "Still Duration", value: $store.durationText, suffix: "seconds")
                        .frame(width: 190)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Export Format")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Export Format", selection: $store.exportFormat) {
                            ForEach(ExportFormat.allCases) { format in
                                Text(format.title).tag(format)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        Text(store.exportFormat.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 220, alignment: .leading)
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Import Target")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Import Target", selection: $store.timelineTarget) {
                            ForEach(TimelineImportTarget.allCases) { target in
                                Text(target.title).tag(target)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        Text(store.timelineTarget.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 220, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Scan folders recursively", isOn: $store.recursive)
                        Toggle("Create a new project timeline", isOn: $store.createProjectTimeline)
                        Toggle("Open XML after conversion", isOn: $store.shouldOpenGeneratedXML)
                    }
                    .toggleStyle(.checkbox)
                }
            }

            ModeExplanation(target: store.timelineTarget, createProject: store.createProjectTimeline)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct SettingField: View {
    let title: String
    @Binding var value: String
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                TextField("4", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 62)
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ModeExplanation: View {
    let target: TimelineImportTarget
    let createProject: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: createProject ? "timeline.selection" : "rectangle.stack.badge.plus")
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 3) {
                Text(createProject ? "Project timeline mode" : "Existing project mode")
                    .font(.callout.weight(.semibold))
                Text(target.modeDetail(createProject: createProject))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ConversionActions: View {
    @ObservedObject var store: ConversionStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary)
                    .font(.callout.weight(.semibold))
                Text("Output: Rec. 2020 HLG \(store.exportFormat.title).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.openOutputDirectory()
            } label: {
                Label("Output", systemImage: "folder")
            }
            Button {
                store.openGeneratedXML()
            } label: {
                Label("XML", systemImage: "doc.badge.gearshape")
            }
            .disabled(!canOpenXML)
            Button {
                store.startConversion()
            } label: {
                Label("Convert", systemImage: "bolt.fill")
                    .frame(minWidth: 96)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canConvert)
            if store.status == .running {
                Button(role: .destructive) {
                    store.stopConversion()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var summary: String {
        switch store.status {
        case .idle:
            return "\(store.sources.count) source item(s) ready"
        case .running:
            return "Conversion is running"
        case .succeeded(let xml, let target):
            return "\(target.title) XML ready: \(xml.lastPathComponent)"
        case .stopped(let xml?, let target?):
            return "Stopped. Partial \(target.title) XML ready: \(xml.lastPathComponent)"
        case .stopped(let xml?, nil):
            return "Stopped. Partial XML ready: \(xml.lastPathComponent)"
        case .stopped(nil, _):
            return "Stopped before a file was completed"
        case .failed(let message):
            return message
        }
    }

    private var canOpenXML: Bool {
        switch store.status {
        case .succeeded, .stopped(.some, _):
            return true
        default:
            return false
        }
    }
}

struct LogPanel: View {
    let logs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity")
                    .font(.headline)
                Spacer()
                Text("\(logs.count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

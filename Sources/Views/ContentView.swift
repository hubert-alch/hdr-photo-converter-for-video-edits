import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ConversionStore

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(store: store)
            Divider()
            HSplitView {
                SourceQueueView(store: store)
                    .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
                DetailView(store: store)
                    .frame(minWidth: 560)
            }
        }
        .background(.regularMaterial)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.chooseFiles()
                } label: {
                    Label("Add Photos", systemImage: "photo.badge.plus")
                }
                Button {
                    store.startConversion()
                } label: {
                    Label("Convert", systemImage: "bolt.fill")
                }
                .disabled(!store.canConvert)
                if store.status == .running {
                    Button(role: .destructive) {
                        store.stopConversion()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                }
            }
        }
    }
}

struct HeaderView: View {
    @ObservedObject var store: ConversionStore

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles.tv")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 42, height: 42)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text("HDR Photo Converter for Video Editors")
                    .font(.title2.weight(.semibold))
                Text("Open-source HDR gain-map photo conversion for Final Cut Pro and DaVinci Resolve.")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            StatusBadge(status: store.status)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

struct StatusBadge: View {
    let status: ConversionStatus

    var body: some View {
        Label(status.label, systemImage: icon)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .foregroundStyle(color)
    }

    private var icon: String {
        switch status {
        case .idle:
            return "checkmark.circle"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .succeeded:
            return "checkmark.seal.fill"
        case .stopped:
            return "stop.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .idle:
            return .secondary
        case .running:
            return .blue
        case .succeeded:
            return .green
        case .stopped:
            return .orange
        case .failed:
            return .red
        }
    }
}

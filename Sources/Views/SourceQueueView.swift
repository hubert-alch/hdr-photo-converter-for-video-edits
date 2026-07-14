import SwiftUI
import UniformTypeIdentifiers

struct SourceQueueView: View {
    @ObservedObject var store: ConversionStore
    @State private var isDropTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Source Queue")
                    .font(.headline)
                Spacer()
                Text("\(store.sources.count)")
                    .foregroundStyle(.secondary)
            }

            if store.sources.isEmpty {
                EmptyQueueView()
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget) {
                        store.addDroppedProviders($0)
                    }
                    .overlay(dropOverlay)
            } else {
                List {
                    ForEach(store.sources) { item in
                        SourceRow(item: item)
                            .contextMenu {
                                Button("Remove") { store.remove(item) }
                            }
                    }
                    .onDelete { indexes in
                        for index in indexes {
                            store.remove(store.sources[index])
                        }
                    }
                }
                .listStyle(.sidebar)
                .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget) {
                    store.addDroppedProviders($0)
                }
                .overlay(dropOverlay)
            }

            HStack {
                Button {
                    store.chooseFiles()
                } label: {
                    Label("Photos", systemImage: "plus")
                }
                Button {
                    store.chooseFolder()
                } label: {
                    Label("Folder", systemImage: "folder.badge.plus")
                }
                Spacer()
                Button("Clear") {
                    store.clear()
                }
                .disabled(store.sources.isEmpty)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var dropOverlay: some View {
        if isDropTarget {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.cyan, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .padding(4)
        }
    }
}

struct EmptyQueueView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("Drop HDR photos here")
                .font(.headline)
            Text("Supports ISO Ultra HDR JPEG and Apple HDR HEIC. SDR photos are identified before conversion.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct SourceRow: View {
    let item: SourceItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let formatDetail = item.formatDetail {
                    Text(formatDetail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private var icon: String {
        switch item.kind {
        case .isoUltraHDRJPEG: return "sparkles.rectangle.stack"
        case .appleHDRGainMap: return "apple.logo"
        case .standardDynamicRange: return "photo"
        case .unsupported: return "exclamationmark.triangle"
        case .folder: return "folder"
        }
    }

    private var color: Color {
        switch item.kind {
        case .isoUltraHDRJPEG: return .cyan
        case .appleHDRGainMap: return .orange
        case .standardDynamicRange: return .secondary
        case .unsupported: return .red
        case .folder: return .blue
        }
    }
}

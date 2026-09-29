import SwiftUI

struct AlbumSidebarView: View {
    @Environment(AppModel.self) private var model
    @State private var searchText = ""

    var body: some View {
        List {
            ForEach(filteredSections) { section in
                Section(section.title) {
                    OutlineGroup(section.nodes, children: \.children) { node in
                        AlbumRow(node: node)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Filter albums")
        .overlay {
            if model.isLoadingAlbums && model.sections.isEmpty {
                ProgressView("Loading albums…")
            } else if model.sections.allSatisfy(\.nodes.isEmpty) && !model.isLoadingAlbums {
                ContentUnavailableView("No Albums", systemImage: "rectangle.stack")
            }
        }
        .navigationSplitViewColumnWidth(min: 230, ideal: 270)
    }

    private var filteredSections: [AlbumSection] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return model.sections }
        return model.sections.compactMap { section in
            let nodes = section.nodes.compactMap { filter($0, query: query) }
            return nodes.isEmpty ? nil : AlbumSection(id: section.id, title: section.title, nodes: nodes)
        }
    }

    private func filter(_ node: AlbumNode, query: String) -> AlbumNode? {
        let matches = node.name.localizedCaseInsensitiveContains(query)
        if let children = node.children {
            let kept = children.compactMap { filter($0, query: query) }
            if matches || !kept.isEmpty {
                var copy = node
                copy.children = matches ? children : kept
                return copy
            }
            return nil
        }
        return matches ? node : nil
    }
}

struct AlbumRow: View {
    @Environment(AppModel.self) private var model
    let node: AlbumNode

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(
                get: { model.checkState(node) == .on },
                set: { _ in model.toggle(node) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Image(systemName: node.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(node.name)
                .lineLimit(1)
                .truncationMode(.tail)

            if model.checkState(node) == .mixed {
                Image(systemName: "minus.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Some albums in this folder are selected")
            }

            Spacer()

            if node.kind != .folder {
                Text("\(node.itemCount)")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(node) }
    }
}

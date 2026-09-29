import Foundation
import Photos

enum AlbumKind {
    case folder
    case userAlbum
    case smartAlbum
    case sharedAlbum
}

struct AlbumNode: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: AlbumKind
    let itemCount: Int
    let collection: PHAssetCollection?
    /// Non-nil (possibly empty) for folders, nil for albums — drives OutlineGroup disclosure.
    var children: [AlbumNode]?

    var leafIDs: [String] {
        if let children { return children.flatMap(\.leafIDs) }
        return kind == .folder ? [] : [id]
    }

    var iconName: String {
        switch kind {
        case .folder: "folder"
        case .userAlbum: "rectangle.stack"
        case .smartAlbum: "gearshape"
        case .sharedAlbum: "person.2"
        }
    }

    static func == (lhs: AlbumNode, rhs: AlbumNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct AlbumSection: Identifiable {
    let id: String
    let title: String
    var nodes: [AlbumNode]
}

enum CheckState {
    case off, on, mixed
}

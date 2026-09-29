import Foundation
import Photos

/// Reads the album structure from PhotoKit and observes library changes.
final class PhotoLibraryService: NSObject, PHPhotoLibraryChangeObserver {
    var onChange: (() -> Void)?
    private var observing = false

    func startObserving() {
        guard !observing else { return }
        observing = true
        PHPhotoLibrary.shared().register(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in self?.onChange?() }
    }

    static let mediaPredicate = NSPredicate(
        format: "mediaType == %d OR mediaType == %d",
        PHAssetMediaType.image.rawValue,
        PHAssetMediaType.video.rawValue
    )

    static func assetCount(in collection: PHAssetCollection) -> Int {
        let options = PHFetchOptions()
        options.predicate = mediaPredicate
        return PHAsset.fetchAssets(in: collection, options: options).count
    }

    /// Blocking; call off the main thread.
    static func loadSections() -> [AlbumSection] {
        var sections: [AlbumSection] = []

        var userNodes: [AlbumNode] = []
        let top = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        top.enumerateObjects { collection, _, _ in
            if let node = node(for: collection) { userNodes.append(node) }
        }
        sections.append(AlbumSection(id: "albums", title: "Albums", nodes: userNodes))

        var smartNodes: [AlbumNode] = []
        let smart = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        smart.enumerateObjects { collection, _, _ in
            guard collection.assetCollectionSubtype != .smartAlbumAllHidden else { return }
            smartNodes.append(AlbumNode(
                id: collection.localIdentifier,
                name: collection.localizedTitle ?? "Untitled",
                kind: .smartAlbum,
                itemCount: assetCount(in: collection),
                collection: collection,
                children: nil
            ))
        }
        sections.append(AlbumSection(id: "smart", title: "Smart Albums", nodes: smartNodes))

        var sharedNodes: [AlbumNode] = []
        let shared = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil)
        shared.enumerateObjects { collection, _, _ in
            sharedNodes.append(AlbumNode(
                id: collection.localIdentifier,
                name: collection.localizedTitle ?? "Untitled",
                kind: .sharedAlbum,
                itemCount: assetCount(in: collection),
                collection: collection,
                children: nil
            ))
        }
        if !sharedNodes.isEmpty {
            sections.append(AlbumSection(id: "shared", title: "Shared Albums", nodes: sharedNodes))
        }

        return sections
    }

    private static func node(for collection: PHCollection) -> AlbumNode? {
        if let list = collection as? PHCollectionList {
            var children: [AlbumNode] = []
            let inner = PHCollectionList.fetchCollections(in: list, options: nil)
            inner.enumerateObjects { child, _, _ in
                if let childNode = node(for: child) { children.append(childNode) }
            }
            return AlbumNode(
                id: list.localIdentifier,
                name: list.localizedTitle ?? "Folder",
                kind: .folder,
                itemCount: 0,
                collection: nil,
                children: children
            )
        }
        if let album = collection as? PHAssetCollection {
            return AlbumNode(
                id: album.localIdentifier,
                name: album.localizedTitle ?? "Untitled",
                kind: .userAlbum,
                itemCount: assetCount(in: album),
                collection: album,
                children: nil
            )
        }
        return nil
    }
}

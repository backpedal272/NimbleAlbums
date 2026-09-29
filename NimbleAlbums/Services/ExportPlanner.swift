import Foundation
import Photos
import UniformTypeIdentifiers

struct SelectedAlbum {
    let collection: PHAssetCollection
    let name: String
    let relativeDir: String
}

/// Expands an album selection into the concrete list of files to write.
enum ExportPlanner {

    static func selectedAlbums(sections: [AlbumSection], selection: Set<String>) -> [SelectedAlbum] {
        var result: [SelectedAlbum] = []
        for section in sections {
            collect(nodes: section.nodes, dir: "", selection: selection, into: &result)
        }
        return result
    }

    private static func collect(
        nodes: [AlbumNode],
        dir: String,
        selection: Set<String>,
        into result: inout [SelectedAlbum]
    ) {
        var usedNames = Set<String>()
        for node in nodes {
            let name = FileNaming.uniqueName(FileNaming.sanitize(node.name), used: &usedNames)
            let path = dir.isEmpty ? name : dir + "/" + name
            if node.kind == .folder {
                collect(nodes: node.children ?? [], dir: path, selection: selection, into: &result)
            } else if selection.contains(node.id), let collection = node.collection {
                result.append(SelectedAlbum(collection: collection, name: node.name, relativeDir: path))
            }
        }
    }

    /// Blocking; call off the main thread for large selections.
    static func makePlan(for albums: [SelectedAlbum]) -> ExportPlan {
        var plan = ExportPlan()
        plan.albumCount = albums.count
        var uniqueAssets = Set<String>()

        for album in albums {
            var usedNames = Set<String>()
            let options = PHFetchOptions()
            options.predicate = PhotoLibraryService.mediaPredicate
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            let assets = PHAsset.fetchAssets(in: album.collection, options: options)

            assets.enumerateObjects { asset, _, _ in
                uniqueAssets.insert(asset.localIdentifier)
                let resources = PHAssetResource.assetResources(for: asset)
                let originalType: PHAssetResourceType = asset.mediaType == .video ? .video : .photo
                let editedType: PHAssetResourceType = asset.mediaType == .video ? .fullSizeVideo : .fullSizePhoto
                guard let original = resources.first(where: { $0.type == originalType }) ?? resources.first else {
                    return
                }

                let prefix = FileNaming.datePrefix(for: asset.creationDate)
                let (stem, ext) = FileNaming.splitExtension(FileNaming.sanitize(original.originalFilename))

                let originalName = FileNaming.uniqueName(
                    ext.isEmpty ? "\(prefix)_\(stem)" : "\(prefix)_\(stem).\(ext)",
                    used: &usedNames
                )
                append(
                    resource: original, asset: asset, album: album, fileName: originalName,
                    variant: .original, to: &plan
                )

                if let edited = resources.first(where: { $0.type == editedType }) {
                    let editedExt = preferredExtension(for: edited)
                        ?? (asset.mediaType == .video ? "mov" : "jpg")
                    let editedName = FileNaming.uniqueName(
                        "\(prefix)_\(stem)_edited.\(editedExt)",
                        used: &usedNames
                    )
                    append(
                        resource: edited, asset: asset, album: album, fileName: editedName,
                        variant: .edited, to: &plan
                    )
                }
            }
        }

        plan.uniqueAssetCount = uniqueAssets.count
        return plan
    }

    private static func append(
        resource: PHAssetResource,
        asset: PHAsset,
        album: SelectedAlbum,
        fileName: String,
        variant: ExportVariant,
        to plan: inout ExportPlan
    ) {
        let size = fileSize(of: resource)
        if let size { plan.knownBytes += size } else { plan.unknownSizeCount += 1 }
        plan.items.append(ExportItem(
            assetID: asset.localIdentifier,
            albumName: album.name,
            relativeDir: album.relativeDir,
            fileName: fileName,
            resource: resource,
            captureDate: asset.creationDate,
            estimatedSize: size,
            variant: variant
        ))
    }

    /// PhotoKit exposes no public file-size API; "fileSize" is the de-facto KVC key.
    /// Treated as optional data everywhere — the app must work when it returns nil.
    static func fileSize(of resource: PHAssetResource) -> Int64? {
        resource.value(forKey: "fileSize") as? Int64
    }

    private static func preferredExtension(for resource: PHAssetResource) -> String? {
        UTType(resource.uniformTypeIdentifier)?.preferredFilenameExtension
    }
}

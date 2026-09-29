import Foundation
import Photos

enum ExportVariant {
    case original
    case edited
}

struct ExportItem: Identifiable {
    let id = UUID()
    let assetID: String
    let albumName: String
    /// Directory path relative to the destination, e.g. "Vacations/Italy 2024".
    let relativeDir: String
    let fileName: String
    let resource: PHAssetResource
    let captureDate: Date?
    let estimatedSize: Int64?
    let variant: ExportVariant

    var relativePath: String {
        relativeDir.isEmpty ? fileName : relativeDir + "/" + fileName
    }
}

struct ExportPlan {
    var items: [ExportItem] = []
    var albumCount = 0
    var uniqueAssetCount = 0
    var knownBytes: Int64 = 0
    var unknownSizeCount = 0
}

enum ConflictPolicy: String, CaseIterable, Identifiable {
    case ask
    case skip
    case overwrite
    case keepBoth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ask: "Ask me"
        case .skip: "Skip existing files"
        case .overwrite: "Overwrite"
        case .keepBoth: "Keep both"
        }
    }
}

enum ConflictAction {
    case skip
    case overwrite
    case keepBoth

    var asPolicy: ConflictPolicy {
        switch self {
        case .skip: .skip
        case .overwrite: .overwrite
        case .keepBoth: .keepBoth
        }
    }
}

struct ConflictRequest: Identifiable {
    let id = UUID()
    let fileName: String
    let albumName: String
    let existingSize: Int64?
    let newSize: Int64

    var sameSize: Bool { existingSize == newSize }
}

struct ExportFailure: Identifiable {
    let id = UUID()
    let item: ExportItem
    let message: String
}

enum ExportError: LocalizedError {
    case cloudUnavailable
    case networkTimeout
    case assetMissing
    case resourceUnavailable
    case destinationFull
    case destinationPermission
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .cloudUnavailable: "iCloud is unreachable. Check your network and iCloud sign-in."
        case .networkTimeout: "The download timed out."
        case .assetMissing: "This item no longer exists in the library."
        case .resourceUnavailable: "No full-quality file is available for this item."
        case .destinationFull: "The destination disk is full."
        case .destinationPermission: "Cannot write to the destination folder."
        case .writeFailed(let detail): detail
        }
    }

    var isRetryable: Bool {
        switch self {
        case .cloudUnavailable, .networkTimeout: true
        default: false
        }
    }

    static func classify(_ error: Error) -> ExportError {
        if let already = error as? ExportError { return already }
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain {
            switch ns.code {
            case NSFileWriteOutOfSpaceError: return .destinationFull
            case NSFileWriteNoPermissionError, NSFileWriteVolumeReadOnlyError: return .destinationPermission
            default: break
            }
        }
        if ns.domain == NSURLErrorDomain {
            return ns.code == NSURLErrorTimedOut ? .networkTimeout : .cloudUnavailable
        }
        if ns.domain == PHPhotosErrorDomain, let code = PHPhotosError.Code(rawValue: ns.code) {
            switch code {
            case .networkAccessRequired: return .cloudUnavailable
            case .identifierNotFound: return .assetMissing
            default: break
            }
        }
        return .writeFailed(ns.localizedDescription)
    }
}

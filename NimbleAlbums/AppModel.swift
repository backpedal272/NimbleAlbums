import Foundation
import Photos
import Observation

@MainActor
@Observable
final class AppModel {
    var authStatus: PHAuthorizationStatus = .notDetermined
    var sections: [AlbumSection] = []
    var isLoadingAlbums = false
    var selection: Set<String> = []

    var destination: URL?
    var conflictPolicy: ConflictPolicy = .ask
    var preventSleep = true

    private(set) var preflight: ExportPlan?
    private(set) var isEstimating = false
    private(set) var freeSpace: Int64?

    var session: ExportSession?
    var showSummary = false

    @ObservationIgnored private let libraryService = PhotoLibraryService()
    @ObservationIgnored private var planTask: Task<Void, Never>?
    @ObservationIgnored private var didBootstrap = false

    var canExport: Bool {
        destination != nil && !selection.isEmpty && !(preflight?.items.isEmpty ?? true)
            && !isEstimating && session == nil
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        authStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else { return }
        destination = DestinationStore.restore()
        refreshFreeSpace()
        libraryService.onChange = { [weak self] in self?.reloadAlbums() }
        libraryService.startObserving()
        reloadAlbums()
    }

    func reloadAlbums() {
        isLoadingAlbums = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let sections = PhotoLibraryService.loadSections()
            guard let self else { return }
            await MainActor.run {
                self.sections = sections
                self.isLoadingAlbums = false
                self.pruneSelection()
                self.schedulePlanRefresh()
            }
        }
    }

    // MARK: - Selection

    func checkState(_ node: AlbumNode) -> CheckState {
        if node.kind != .folder {
            return selection.contains(node.id) ? .on : .off
        }
        let leaves = node.leafIDs
        guard !leaves.isEmpty else { return .off }
        let selectedCount = leaves.count { selection.contains($0) }
        if selectedCount == 0 { return .off }
        return selectedCount == leaves.count ? .on : .mixed
    }

    func toggle(_ node: AlbumNode) {
        if node.kind == .folder {
            let leaves = node.leafIDs
            if checkState(node) == .on {
                selection.subtract(leaves)
            } else {
                selection.formUnion(leaves)
            }
        } else if selection.contains(node.id) {
            selection.remove(node.id)
        } else {
            selection.insert(node.id)
        }
        schedulePlanRefresh()
    }

    private func pruneSelection() {
        let validIDs = Set(sections.flatMap { $0.nodes.flatMap(\.leafIDs) })
        selection.formIntersection(validIDs)
    }

    // MARK: - Pre-flight

    func schedulePlanRefresh() {
        planTask?.cancel()
        preflight = nil
        guard !selection.isEmpty else {
            isEstimating = false
            return
        }
        isEstimating = true
        let sections = self.sections
        let selection = self.selection
        planTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let albums = ExportPlanner.selectedAlbums(sections: sections, selection: selection)
            let plan = await Task.detached(priority: .userInitiated) {
                ExportPlanner.makePlan(for: albums)
            }.value
            guard !Task.isCancelled, let self else { return }
            self.preflight = plan
            self.isEstimating = false
        }
    }

    // MARK: - Destination

    func setDestination(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        DestinationStore.save(url)
        destination = url
        refreshFreeSpace()
    }

    func refreshFreeSpace() {
        guard let destination else {
            freeSpace = nil
            return
        }
        let values = try? destination.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        freeSpace = values?.volumeAvailableCapacityForImportantUsage
    }

    var spaceWarning: Bool {
        guard let preflight, let freeSpace else { return false }
        return preflight.knownBytes > freeSpace
    }

    // MARK: - Export

    func startExport() {
        guard canExport, let destination, let plan = preflight else { return }
        let newSession = ExportSession(
            items: plan.items,
            destination: destination,
            conflictPolicy: conflictPolicy,
            preventSleep: preventSleep
        )
        session = newSession
        newSession.start()
    }

    func retryFailed() {
        guard let previous = session, let destination else { return }
        let failedItems = previous.failures.map(\.item)
        guard !failedItems.isEmpty else { return }
        showSummary = false
        let newSession = ExportSession(
            items: failedItems,
            destination: destination,
            conflictPolicy: previous.conflictPolicy,
            preventSleep: preventSleep
        )
        session = newSession
        newSession.start()
    }

    func finishSession() {
        showSummary = false
        session = nil
        refreshFreeSpace()
    }
}

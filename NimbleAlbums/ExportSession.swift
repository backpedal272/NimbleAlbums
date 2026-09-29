import Foundation
import Photos
import Observation

/// Blocks workers while the export is paused.
actor PauseGate {
    private var isPaused = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if !paused {
            let resumed = waiters
            waiters.removeAll()
            resumed.forEach { $0.resume() }
        }
    }

    func waitIfPaused() async {
        while isPaused {
            await withCheckedContinuation { waiters.append($0) }
        }
    }
}

/// One export run: downloads items with bounded concurrency, resolves conflicts,
/// tracks progress, and supports pause/resume/cancel and per-item retry.
@MainActor
@Observable
final class ExportSession {
    enum Phase: Equatable {
        case running, paused, cancelling, finished
    }

    let destination: URL
    let preventSleep: Bool
    private let items: [ExportItem]

    private(set) var phase: Phase = .running
    private(set) var doneCount = 0
    private(set) var skippedCount = 0
    private(set) var failures: [ExportFailure] = []
    private(set) var bytesWritten: Int64 = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var startedAt = Date()

    var totalCount: Int { items.count }
    var finishedCount: Int { doneCount + skippedCount + failures.count }
    var wasCancelled = false

    private(set) var inFlight: [UUID: (name: String, fraction: Double)] = [:]

    var fractionCompleted: Double {
        guard totalCount > 0 else { return 0 }
        let progress = Double(finishedCount) + inFlight.values.reduce(0) { $0 + $1.fraction }
        return min(1, progress / Double(totalCount))
    }

    var conflictPolicy: ConflictPolicy
    private(set) var pendingConflict: ConflictRequest?
    @ObservationIgnored private var conflictQueue: [(ConflictRequest, CheckedContinuation<ConflictAction, Never>)] = []

    var destinationFullAlert = false

    @ObservationIgnored private let gate = PauseGate()
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private let power = PowerAssertion()
    @ObservationIgnored private let fileManager = FileManager.default
    private let maxConcurrent = 4

    init(items: [ExportItem], destination: URL, conflictPolicy: ConflictPolicy, preventSleep: Bool) {
        self.items = items
        self.destination = destination
        self.conflictPolicy = conflictPolicy
        self.preventSleep = preventSleep
    }

    // MARK: - Control

    func start() {
        startedAt = Date()
        if preventSleep { power.begin(reason: "Exporting photos") }
        runTask = Task { await run() }
    }

    func pause() {
        guard phase == .running else { return }
        phase = .paused
        power.end()
        Task { await gate.setPaused(true) }
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .running
        if preventSleep { power.begin(reason: "Exporting photos") }
        Task { await gate.setPaused(false) }
    }

    func cancel() {
        guard phase == .running || phase == .paused else { return }
        phase = .cancelling
        wasCancelled = true
        runTask?.cancel()
        // Release paused workers so they can observe cancellation and bail out.
        Task { await gate.setPaused(false) }
        // Unblock any workers waiting on a conflict answer.
        let queued = conflictQueue
        conflictQueue.removeAll()
        pendingConflict = nil
        queued.forEach { $0.1.resume(returning: .skip) }
    }

    // MARK: - Run loop

    private func run() async {
        let all = items
        await withTaskGroup(of: Void.self) { group in
            var index = 0
            func addNext() {
                guard index < all.count else { return }
                let item = all[index]
                index += 1
                group.addTask { await self.process(item) }
            }
            for _ in 0..<maxConcurrent { addNext() }
            while await group.next() != nil { addNext() }
        }
        power.end()
        elapsed = Date().timeIntervalSince(startedAt)
        phase = .finished
    }

    private func process(_ item: ExportItem) async {
        await gate.waitIfPaused()
        guard !Task.isCancelled, phase != .cancelling else { return }

        let dirURL = destination.appendingPathComponent(item.relativeDir, isDirectory: true)
        var finalURL = dirURL.appendingPathComponent(item.fileName)
        let tempURL = dirURL.appendingPathComponent(".\(UUID().uuidString).nimblepart")

        inFlight[item.id] = (item.fileName, 0)
        defer { inFlight[item.id] = nil }

        do {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
            try await download(item, to: tempURL)

            let newSize = (try? fileManager.attributesOfItem(atPath: tempURL.path)[.size] as? Int64)
                .flatMap { $0 } ?? item.estimatedSize ?? 0

            if fileManager.fileExists(atPath: finalURL.path) {
                let existingSize = (try? fileManager.attributesOfItem(atPath: finalURL.path)[.size] as? Int64)
                    .flatMap { $0 }
                let request = ConflictRequest(
                    fileName: item.fileName,
                    albumName: item.albumName,
                    existingSize: existingSize,
                    newSize: newSize
                )
                switch await resolveConflict(request) {
                case .skip:
                    try? fileManager.removeItem(at: tempURL)
                    skippedCount += 1
                    return
                case .overwrite:
                    _ = try fileManager.replaceItemAt(finalURL, withItemAt: tempURL)
                case .keepBoth:
                    finalURL = availableURL(near: finalURL)
                    try fileManager.moveItem(at: tempURL, to: finalURL)
                }
            } else {
                try fileManager.moveItem(at: tempURL, to: finalURL)
            }

            setFileDates(of: finalURL, to: item.captureDate)
            bytesWritten += newSize
            doneCount += 1
        } catch {
            try? fileManager.removeItem(at: tempURL)
            let classified = ExportError.classify(error)
            failures.append(ExportFailure(item: item, message: classified.localizedDescription))
            if case .destinationFull = classified {
                destinationFullAlert = true
                pause()
            }
        }
    }

    private func download(_ item: ExportItem, to url: URL) async throws {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let itemID = item.id
        options.progressHandler = { [weak self] fraction in
            Task { @MainActor in
                self?.inFlight[itemID]?.fraction = fraction
            }
        }

        var attempt = 0
        let backoffSeconds: [UInt64] = [2, 8, 30]
        while true {
            do {
                try? fileManager.removeItem(at: url)
                try await PHAssetResourceManager.default()
                    .writeData(for: item.resource, toFile: url, options: options)
                return
            } catch {
                attempt += 1
                let classified = ExportError.classify(error)
                guard classified.isRetryable, attempt <= backoffSeconds.count, !Task.isCancelled else {
                    throw classified
                }
                try? await Task.sleep(nanoseconds: backoffSeconds[attempt - 1] * 1_000_000_000)
                await gate.waitIfPaused()
                if Task.isCancelled || phase == .cancelling { throw classified }
            }
        }
    }

    // MARK: - Conflicts

    private func resolveConflict(_ request: ConflictRequest) async -> ConflictAction {
        switch conflictPolicy {
        case .skip: return .skip
        case .overwrite: return .overwrite
        case .keepBoth: return .keepBoth
        case .ask:
            return await withCheckedContinuation { continuation in
                conflictQueue.append((request, continuation))
                presentNextConflictIfNeeded()
            }
        }
    }

    private func presentNextConflictIfNeeded() {
        guard pendingConflict == nil, let first = conflictQueue.first else { return }
        pendingConflict = first.0
    }

    func answerConflict(_ action: ConflictAction, applyToAll: Bool) {
        guard let current = pendingConflict,
              let index = conflictQueue.firstIndex(where: { $0.0.id == current.id }) else { return }
        let (_, continuation) = conflictQueue.remove(at: index)
        pendingConflict = nil

        if applyToAll {
            conflictPolicy = action.asPolicy
            let rest = conflictQueue
            conflictQueue.removeAll()
            rest.forEach { $0.1.resume(returning: action) }
        }
        continuation.resume(returning: action)
        presentNextConflictIfNeeded()
    }

    // MARK: - Helpers

    private func availableURL(near url: URL) -> URL {
        let dir = url.deletingLastPathComponent()
        let (stem, ext) = FileNaming.splitExtension(url.lastPathComponent)
        var n = 2
        while true {
            let name = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
            let candidate = dir.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }

    private func setFileDates(of url: URL, to date: Date?) {
        guard let date else { return }
        try? fileManager.setAttributes(
            [.creationDate: date, .modificationDate: date],
            ofItemAtPath: url.path
        )
    }

    func reportText() -> String {
        var lines = [
            "Nimble Albums export report — \(Date().formatted())",
            "Destination: \(destination.path)",
            "Exported: \(doneCount)   Skipped: \(skippedCount)   Failed: \(failures.count)",
            "",
        ]
        for failure in failures {
            lines.append("FAILED  \(failure.item.relativePath) — \(failure.message)")
        }
        return lines.joined(separator: "\n")
    }
}

import SwiftUI
import AppKit

struct SummarySheet: View {
    @Environment(AppModel.self) private var model
    var session: ExportSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: iconName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(session.failures.isEmpty && !session.wasCancelled ? Color.green : Color.orange)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                GridRow {
                    Text("Exported").foregroundStyle(.secondary)
                    Text("\(session.doneCount)").monospacedDigit()
                }
                GridRow {
                    Text("Skipped").foregroundStyle(.secondary)
                    Text("\(session.skippedCount)").monospacedDigit()
                }
                GridRow {
                    Text("Failed").foregroundStyle(.secondary)
                    Text("\(session.failures.count)").monospacedDigit()
                }
                GridRow {
                    Text("Data written").foregroundStyle(.secondary)
                    Text(session.bytesWritten.formatted(.byteCount(style: .file))).monospacedDigit()
                }
                GridRow {
                    Text("Elapsed").foregroundStyle(.secondary)
                    Text(elapsedText).monospacedDigit()
                }
            }

            if !session.failures.isEmpty {
                GroupBox("Failed items") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(session.failures) { failure in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(failure.item.relativePath)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(failure.message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                    }
                    .frame(maxHeight: 160)
                }
            }

            HStack {
                Button("Copy Report") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(session.reportText(), forType: .string)
                }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([session.destination])
                }
                Spacer()
                if !session.failures.isEmpty {
                    Button("Retry Failed") { model.retryFailed() }
                }
                Button("Done") { model.finishSession() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 480)
    }

    private var title: String {
        if session.wasCancelled { return "Export Cancelled" }
        return session.failures.isEmpty ? "Export Complete" : "Export Finished with Errors"
    }

    private var iconName: String {
        if session.wasCancelled { return "xmark.circle.fill" }
        return session.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var elapsedText: String {
        let seconds = Int(session.elapsed.rounded())
        let (h, m, s) = (seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        if h > 0 { return String(format: "%dh %02dm %02ds", h, m, s) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }
}

struct ConflictSheet: View {
    var session: ExportSession
    let request: ConflictRequest
    @State private var applyToAll = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("File already exists", systemImage: "doc.on.doc")
                .font(.headline)
            Text("“\(request.fileName)” already exists in “\(request.albumName)”.")
            Text(detailText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Toggle("Apply to all remaining conflicts", isOn: $applyToAll)
            HStack {
                Button("Skip") { answer(.skip) }
                Button("Keep Both") { answer(.keepBoth) }
                Spacer()
                Button("Overwrite") { answer(.overwrite) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private var detailText: String {
        if request.sameSize {
            return "The existing file has the same size — it is likely the same file."
        }
        let existing = request.existingSize.map { $0.formatted(.byteCount(style: .file)) } ?? "unknown size"
        let new = request.newSize.formatted(.byteCount(style: .file))
        return "The existing file has a different size (existing: \(existing), new: \(new))."
    }

    private func answer(_ action: ConflictAction) {
        session.answerConflict(action, applyToAll: applyToAll)
    }
}

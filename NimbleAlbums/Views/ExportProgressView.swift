import SwiftUI

struct ExportProgressView: View {
    @Environment(AppModel.self) private var model
    var session: ExportSession
    @State private var confirmCancel = false

    var body: some View {
        @Bindable var session = session
        VStack(alignment: .leading, spacing: 16) {
            ProgressView(value: session.fractionCompleted) {
                HStack {
                    Text(phaseTitle).font(.headline)
                    Spacer()
                    Text(session.fractionCompleted.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 24) {
                stat("Exported", count: session.doneCount, color: .green)
                stat("Skipped", count: session.skippedCount, color: .secondary)
                stat("Failed", count: session.failures.count, color: session.failures.isEmpty ? .secondary : .red)
                stat("Remaining", count: session.totalCount - session.finishedCount, color: .secondary)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(session.bytesWritten.formatted(.byteCount(style: .file)))
                        .font(.title3.weight(.medium))
                        .monospacedDigit()
                    Text("written").font(.caption).foregroundStyle(.secondary)
                }
            }

            GroupBox("Downloading") {
                let current = session.inFlight.values.sorted { $0.name < $1.name }
                if current.isEmpty {
                    Text(session.phase == .paused ? "Paused" : "Waiting…")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(current, id: \.name) { entry in
                            HStack {
                                Text(entry.name)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                ProgressView(value: entry.fraction)
                                    .frame(width: 120)
                            }
                        }
                    }
                    .padding(4)
                }
            }

            Spacer()

            HStack {
                if session.phase == .paused {
                    Button("Resume") { session.resume() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Pause") { session.pause() }
                        .disabled(session.phase != .running)
                }
                Button("Cancel", role: .destructive) { confirmCancel = true }
                    .disabled(session.phase == .cancelling || session.phase == .finished)
                Spacer()
            }
        }
        .padding(20)
        .navigationTitle("Exporting")
        .onChange(of: session.phase) { _, newPhase in
            if newPhase == .finished { model.showSummary = true }
        }
        .alert("Destination is full", isPresented: $session.destinationFullAlert) {
            Button("OK") { }
        } message: {
            Text("The export was paused because the destination disk ran out of space. Free some space, then resume.")
        }
        .confirmationDialog("Cancel this export?", isPresented: $confirmCancel) {
            Button("Cancel Export", role: .destructive) { session.cancel() }
            Button("Keep Exporting", role: .cancel) { }
        } message: {
            Text("Files already exported remain in place.")
        }
    }

    private var phaseTitle: String {
        switch session.phase {
        case .running: "Exporting \(session.totalCount) files…"
        case .paused: "Paused"
        case .cancelling: "Cancelling…"
        case .finished: "Finished"
        }
    }

    private func stat(_ label: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading) {
            Text("\(count)")
                .font(.title3.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

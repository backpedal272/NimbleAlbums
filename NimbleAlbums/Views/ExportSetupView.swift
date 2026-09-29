import SwiftUI
import UniformTypeIdentifiers

struct ExportSetupView: View {
    @Environment(AppModel.self) private var model
    @State private var showFolderPicker = false

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Destination") {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(model.destination?.path(percentEncoded: false) ?? "No folder selected")
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(model.destination == nil ? .secondary : .primary)
                        Spacer()
                        Button("Choose…") { showFolderPicker = true }
                    }
                    .padding(4)
                }

                GroupBox("Options") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("If a file already exists:", selection: $model.conflictPolicy) {
                            ForEach(ConflictPolicy.allCases) { policy in
                                Text(policy.label).tag(policy)
                            }
                        }
                        .fixedSize()
                        Toggle("Prevent the Mac from sleeping while exporting", isOn: $model.preventSleep)
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Export Summary") {
                    summaryContent
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Spacer()
                    Button("Export") { model.startExport() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!model.canExport)
                }
            }
            .padding(20)
        }
        .navigationTitle("Nimble Albums")
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                model.setDestination(url)
            }
        }
    }

    @ViewBuilder
    private var summaryContent: some View {
        if model.selection.isEmpty {
            Label("Select one or more albums in the sidebar.", systemImage: "sidebar.left")
                .foregroundStyle(.secondary)
        } else if model.isEstimating {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Estimating…").foregroundStyle(.secondary)
            }
        } else if let plan = model.preflight {
            VStack(alignment: .leading, spacing: 6) {
                summaryRow(
                    "Albums",
                    value: "\(plan.albumCount)"
                )
                summaryRow(
                    "Files to export",
                    value: "\(plan.items.count) (\(plan.uniqueAssetCount) unique items)"
                )
                summaryRow(
                    "Estimated size",
                    value: sizeText(for: plan)
                )
                if let freeSpace = model.freeSpace {
                    summaryRow(
                        "Free space at destination",
                        value: freeSpace.formatted(.byteCount(style: .file))
                    )
                }
                if model.spaceWarning {
                    Label(
                        "The export may not fit on the destination volume.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private func sizeText(for plan: ExportPlan) -> String {
        let formatted = plan.knownBytes.formatted(.byteCount(style: .file))
        if plan.unknownSizeCount > 0 {
            return "≈ at least \(formatted) (\(plan.unknownSizeCount) items of unknown size)"
        }
        return "≈ \(formatted)"
    }
}

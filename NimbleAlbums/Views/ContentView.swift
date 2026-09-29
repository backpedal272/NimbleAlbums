import SwiftUI
import Photos

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            switch model.authStatus {
            case .notDetermined:
                ProgressView("Requesting access to your photo library…")
            case .denied, .restricted:
                AccessDeniedView()
            default:
                NavigationSplitView {
                    AlbumSidebarView()
                } detail: {
                    detail
                }
            }
        }
        .task { await model.bootstrap() }
        .frame(minWidth: 780, minHeight: 540)
        .sheet(isPresented: $model.showSummary) {
            if let session = model.session {
                SummarySheet(session: session)
            }
        }
        .sheet(item: conflictBinding) { request in
            if let session = model.session {
                ConflictSheet(session: session, request: request)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        VStack(spacing: 0) {
            if model.authStatus == .limited {
                LimitedAccessBanner()
            }
            if let session = model.session {
                ExportProgressView(session: session)
            } else {
                ExportSetupView()
            }
        }
    }

    private var conflictBinding: Binding<ConflictRequest?> {
        Binding(
            get: { model.session?.pendingConflict },
            set: { _ in }
        )
    }
}

struct AccessDeniedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Access to Photos", systemImage: "photo.badge.exclamationmark")
        } description: {
            Text("Nimble Albums needs access to your photo library to export your albums. Enable it in System Settings › Privacy & Security › Photos, then relaunch the app.")
        } actions: {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

struct LimitedAccessBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("You've granted access to only part of your library. Some albums and photos may be missing.")
                .font(.callout)
            Spacer()
            Button("Change…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.12))
    }
}

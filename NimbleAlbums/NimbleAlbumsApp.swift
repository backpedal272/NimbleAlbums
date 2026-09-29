import SwiftUI

@main
struct NimbleAlbumsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .onAppear { appDelegate.model = model }
        }
        .defaultSize(width: 900, height: 620)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let session = model?.session,
              session.phase == .running || session.phase == .paused else {
            return .terminateNow
        }
        let alert = NSAlert()
        alert.messageText = "An export is running"
        alert.informativeText = "Quitting cancels the export. Files already exported remain in place."
        alert.addButton(withTitle: "Cancel Export and Quit")
        alert.addButton(withTitle: "Keep Exporting")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}

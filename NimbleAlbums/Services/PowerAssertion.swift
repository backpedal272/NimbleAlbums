import Foundation

/// Keeps the system awake (and the app out of App Nap) while an export runs.
final class PowerAssertion {
    private var token: NSObjectProtocol?

    func begin(reason: String) {
        guard token == nil else { return }
        token = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .userInitiated],
            reason: reason
        )
    }

    func end() {
        if let token {
            ProcessInfo.processInfo.endActivity(token)
            self.token = nil
        }
    }

    deinit { end() }
}

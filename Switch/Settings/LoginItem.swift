import Foundation
import os.log
import ServiceManagement

/// Thin observable wrapper around SMAppService.mainApp so the Settings toggle
/// can read and write the "launch at login" state.
final class LoginItem: ObservableObject {
    private static let logger = Logger(subsystem: "io.warpnine.switch", category: "LoginItem")

    @Published private(set) var enabled = false
    @Published private(set) var requiresApproval = false

    init() { refresh() }

    func refresh() {
        let status = SMAppService.mainApp.status
        enabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func set(_ value: Bool) {
        do {
            try value ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        } catch {
            Self.logger.error("SMAppService error: \(error.localizedDescription)")
        }
        refresh()
    }
}

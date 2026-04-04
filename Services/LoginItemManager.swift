import ServiceManagement
import Observation
import os

@Observable
final class LoginItemManager {
    private static let logger = Logger(subsystem: "com.ohresearch.QuickOpen", category: "LoginItemManager")

    var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                    Self.logger.info("Login item registered")
                } else {
                    try SMAppService.mainApp.unregister()
                    Self.logger.info("Login item unregistered")
                }
            } catch {
                Self.logger.error("Failed to update login item: \(error.localizedDescription)")
            }
        }
    }
}

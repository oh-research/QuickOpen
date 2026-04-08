import Foundation
import Observation

/// Pure observable app state. Behavior lives in `AppCoordinator`.
@Observable
@MainActor
final class AppState {
    /// Whether initial setup (permissions) has been completed.
    var setupCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: "setupCompleted") }
        set { UserDefaults.standard.set(newValue, forKey: "setupCompleted") }
    }

    /// Whether the setup window should be shown on launch.
    var showSetupWindow: Bool = false

    /// Master switch: when false, all triggers are inactive.
    /// Defaults to true on first launch.
    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "isEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "isEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "isEnabled") }
    }
}

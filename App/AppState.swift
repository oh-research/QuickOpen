import Foundation
import Observation

/// Pure observable app state. Behavior lives in `AppCoordinator`.
///
/// All persisted flags are stored properties (not computed) so the
/// `@Observable` macro tracks their mutations — SwiftUI views bound to
/// them update reactively. UserDefaults sync happens in `didSet`.
@Observable
@MainActor
final class AppState {
    /// Whether initial setup (permissions) has been completed.
    var setupCompleted: Bool = AppState.loadBool(key: Key.setupCompleted, fallback: false) {
        didSet {
            UserDefaults.standard.set(setupCompleted, forKey: Key.setupCompleted)
        }
    }

    /// Whether the setup window should be shown on launch.
    var showSetupWindow: Bool = false

    /// Master switch: when false, all triggers are inactive.
    /// Defaults to true on first launch.
    var isEnabled: Bool = AppState.loadBool(key: Key.isEnabled, fallback: true) {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Key.isEnabled)
        }
    }

    // MARK: - Persistence

    private enum Key {
        static let setupCompleted = "setupCompleted"
        static let isEnabled = "isEnabled"
    }

    private static func loadBool(key: String, fallback: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return fallback
        }
        return UserDefaults.standard.bool(forKey: key)
    }
}

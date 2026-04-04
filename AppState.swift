import Observation
import SwiftUI
import os

/// Central observable state for the QuickOpen app.
@Observable
@MainActor
final class AppState {
    private static let logger = Logger(subsystem: "com.ohresearch.QuickOpen", category: "AppState")

    let configManager = ConfigManager()
    let permissionManager = PermissionManager()
    let shortcutService = ShortcutService()
    let eventMonitorService = EventMonitorService()
    let loginItemManager = LoginItemManager()

    /// Whether initial setup (permissions) has been completed
    var setupCompleted: Bool {
        get {
            UserDefaults.standard.bool(forKey: "setupCompleted")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "setupCompleted")
        }
    }

    /// Whether the setup window should be shown
    var showSetupWindow: Bool = false

    /// Tracks the last known accessibility state so we can react to changes.
    private var lastKnownAccessibility = false
    private var triggersConfigured = false

    init() {
        if !setupCompleted || !permissionManager.allPermissionsGranted {
            showSetupWindow = true
        } else {
            setupTriggers()
        }
        lastKnownAccessibility = permissionManager.accessibilityGranted
        permissionManager.onPermissionsChanged = { [weak self] in
            self?.handleAccessibilityChange()
        }
        permissionManager.startPeriodicCheck(interval: 1, includeAutomation: false)
        // Permission changes are detected by: (1) the CGEventTap callback
        // (tapDisabledByUserInput), (2) EventMonitorService's own 2-second
        // periodic AXIsProcessTrusted() check, and (3) PermissionGuideView's
        // polling while visible.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cleanup()
            }
        }
    }

    func cleanup() {
        eventMonitorService.stop()
        permissionManager.stopPeriodicCheck()
        shortcutService.unregisterAll()
        triggersConfigured = false
        Self.logger.info("AppState cleanup completed")
    }

    /// Called by the periodic permission check (via observation) to react to
    /// accessibility permission changes at runtime.
    func handleAccessibilityChange() {
        let current = permissionManager.accessibilityGranted
        guard current != lastKnownAccessibility else { return }
        lastKnownAccessibility = current

        if current {
            if !triggersConfigured {
                Self.logger.info("Accessibility permission became available after launch — configuring triggers")
                setupTriggers()
            } else {
                Self.logger.info("Accessibility permission restored — restarting event monitor")
                if !eventMonitorService.isActive {
                    eventMonitorService.start()
                }
            }
        } else {
            Self.logger.warning("Accessibility permission revoked — stopping event monitor")
            eventMonitorService.stop()
        }
    }

    func completeSetup() {
        setupCompleted = true
        showSetupWindow = false
        setupTriggers()
    }

    func setupTriggers() {
        guard !triggersConfigured else { return }
        triggersConfigured = true

        // Register keyboard shortcuts
        registerAllKeyboardShortcuts()

        // Setup mouse/trackpad event monitor
        eventMonitorService.onTriggerDetected = { [weak self] trigger, completion in
            guard let self else { completion(); return }
            self.handleTrigger(trigger)
            completion()
        }

        eventMonitorService.onPermissionLost = { [weak self] in
            guard let self else { return }
            self.permissionManager.checkPermissions(includeAutomation: false)
        }

        if permissionManager.accessibilityGranted {
            eventMonitorService.start()
        }
    }

    func refreshTriggers() {
        shortcutService.unregisterAll()
        eventMonitorService.stop()
        triggersConfigured = false
        setupTriggers()
    }

    func handleTrigger(_ trigger: TriggerType) {
        let mappings = configManager.mappings
        guard let mapping = TriggerMatcher.match(trigger: trigger, mappings: mappings) else {
            Self.logger.debug("No mapping found for trigger: \(String(describing: trigger))")
            return
        }

        Self.logger.info("Executing mapping: \(mapping.name)")
        Task {
            await ActionExecutor.execute(mapping: mapping)
        }
    }

    // MARK: - Keyboard Shortcuts

    private func registerAllKeyboardShortcuts() {
        for mapping in configManager.mappings where mapping.isEnabled {
            if case .keyboard(let keyCombo) = mapping.trigger {
                let shortcutID = mapping.id.uuidString
                shortcutService.register(shortcutID: shortcutID, keyCombo: keyCombo) { [weak self] in
                    self?.handleTrigger(.keyboard(keyCombo: keyCombo))
                }
            }
        }
    }
}

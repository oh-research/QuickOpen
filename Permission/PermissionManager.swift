import AppKit
import Observation
import os

@Observable
final class PermissionManager {
    private static let logger = Logger(subsystem: "com.ohresearch.QuickOpen", category: "PermissionManager")

    private(set) var accessibilityGranted = false
    private(set) var automationGranted = false
    private var checkTimer: Timer?

    /// Called after each periodic permission check completes.
    var onPermissionsChanged: (() -> Void)?

    var allPermissionsGranted: Bool {
        accessibilityGranted && automationGranted
    }

    init() {
        checkPermissions()
    }

    func checkPermissions(includeAutomation: Bool = true) {
        let ax = AXIsProcessTrusted()

        // Notify immediately on accessibility change (cheap check) so the
        // event monitor can be stopped/restarted without waiting for the
        // heavier Automation check.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let changed = self.accessibilityGranted != ax
            self.accessibilityGranted = ax
            if changed {
                Self.logger.info("Accessibility permission changed to \(ax)")
                self.onPermissionsChanged?()
            }
        }

        guard includeAutomation else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let automation = await self.checkAutomationPermission()
            if self.automationGranted != automation {
                self.automationGranted = automation
                Self.logger.info("Automation permission changed to \(automation)")
                self.onPermissionsChanged?()
            }
        }
    }

    func startPeriodicCheck(interval: TimeInterval = 1, includeAutomation: Bool = false) {
        stopPeriodicCheck()
        // Ensure timer runs on main thread for UI updates
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.checkPermissions(includeAutomation: includeAutomation)
            self.checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.checkPermissions(includeAutomation: includeAutomation)
            }
        }
    }

    func stopPeriodicCheck() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // Check again after a short delay — the system dialog may grant immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkPermissions()
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    private func checkAutomationPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let script = NSAppleScript(source: """
                    tell application "Finder" to return name
                """)
                var error: NSDictionary?
                script?.executeAndReturnError(&error)

                if let error = error,
                   let errorNumber = error[NSAppleScript.errorNumber] as? Int {
                    switch errorNumber {
                    case -1743:
                        Self.logger.warning("Automation permission denied (error -1743)")
                        continuation.resume(returning: false)
                    case -600:
                        Self.logger.info("Finder not running (-600), automation permission still considered granted")
                        continuation.resume(returning: true)
                    default:
                        Self.logger.error("Unexpected AppleScript error checking automation: \(errorNumber)")
                        continuation.resume(returning: false)
                    }
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
    }
}

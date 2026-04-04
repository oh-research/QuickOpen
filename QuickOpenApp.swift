import AppKit
import SwiftUI

@main
struct QuickOpenApp: App {
    @State private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    init() {
        // Check for existing instance
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.ohresearch.QuickOpen")
        if runningApps.count > 1 {
            if let existing = runningApps.first(where: { $0 != NSRunningApplication.current }) {
                existing.activate()
            }
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: menuBarIconName)
                .onAppear {
                    if appState.showSetupWindow {
                        appState.showSetupWindow = false
                        openWindow(id: "setup")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }

        Window("QuickOpen Setup", id: "setup") {
            SetupWindowContent(appState: appState)
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .defaultPosition(.center)
    }

    private var menuBarIconName: String {
        if !appState.permissionManager.allPermissionsGranted {
            return "exclamationmark.arrow.trianglehead.counterclockwise.rotate.90"
        }
        if appState.configManager.mappings.allSatisfy({ !$0.isEnabled }) {
            return "folder.badge.minus"
        }
        return "folder.badge.gearshape"
    }
}

/// Wrapper for the setup / "How to Use" window.
struct SetupWindowContent: View {
    let appState: AppState

    var body: some View {
        PermissionGuideView {
            appState.completeSetup()
            NSApp.keyWindow?.close()
        }
        .environment(appState)
    }
}

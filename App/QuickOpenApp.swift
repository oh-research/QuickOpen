import AppKit
import SwiftUI

@main
struct QuickOpenApp: App {
    @State private var coordinator = AppCoordinator()
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
                .environment(coordinator)
        } label: {
            Image(nsImage: MenuBarIcon.make())
                .onAppear {
                    if coordinator.state.showSetupWindow {
                        coordinator.state.showSetupWindow = false
                        openWindow(id: "setup")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
        }

        // The SwiftUI Settings scene ignores .windowResizability modifiers and
        // always produces a fixed-size window. A regular Window scene honors
        // .contentMinSize, so the user can drag the edges to resize.
        Window("QuickOpen Settings", id: "settings") {
            SettingsView()
                .environment(coordinator)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
        .defaultPosition(.center)

        Window("QuickOpen Setup", id: "setup") {
            SetupWindowContent(coordinator: coordinator)
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .defaultPosition(.center)

        Window("About QuickOpen", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .defaultPosition(.center)
    }
}

/// Wrapper for the setup / "How to Use" window.
struct SetupWindowContent: View {
    let coordinator: AppCoordinator

    var body: some View {
        PermissionGuideView {
            coordinator.completeSetup()
            NSApp.keyWindow?.close()
        }
        .environment(coordinator)
    }
}

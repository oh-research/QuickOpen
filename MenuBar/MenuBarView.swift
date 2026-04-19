import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Enable", isOn: Binding(
            get: { coordinator.state.isEnabled },
            set: { coordinator.setEnabled($0) }
        ))

        Divider()

        Button("Settings...") {
            openAndActivateWindow(id: "settings")
        }
        .keyboardShortcut(",")

        Button("How to Use...") {
            openAndActivateWindow(id: "setup")
        }

        Button("About QuickOpen") {
            openAndActivateWindow(id: "about")
        }

        Divider()

        Button("Quit QuickOpen") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// LSUIElement apps don't get foreground focus just by opening a window.
    /// Activating AFTER openWindow ensures the window reaches the front.
    private func openAndActivateWindow(id: String) {
        openWindow(id: id)
        NSApp.activate()
    }
}

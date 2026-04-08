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

        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",")

        Button("How to Use...") {
            openWindow(id: "setup")
        }

        Button("About QuickOpen") {
            openWindow(id: "about")
        }

        Divider()

        Button("Quit QuickOpen") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

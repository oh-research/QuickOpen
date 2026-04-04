import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        SettingsLink {
            Text("Settings...")
        }

        Button("How to Use...") {
            openWindow(id: "setup")
        }

        Divider()

        Button("Quit QuickOpen") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

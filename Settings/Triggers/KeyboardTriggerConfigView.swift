import SwiftUI

/// Configures a keyboard-shortcut trigger by recording a key combination.
struct KeyboardTriggerConfigView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Binding var recordedKeyCombo: ShortcutService.KeyCombo?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Shortcut:")
                if let combo = recordedKeyCombo {
                    Text(combo.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Text("Not set")
                        .foregroundStyle(.secondary)
                }

                Button(coordinator.shortcutService.isRecording ? "Cancel" : "Record Shortcut") {
                    toggleRecording()
                }
            }

            if coordinator.shortcutService.isRecording {
                Text("Press a key combination...")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .padding(8)
    }

    private func toggleRecording() {
        if coordinator.shortcutService.isRecording {
            coordinator.shortcutService.stopRecording()
        } else {
            coordinator.shortcutService.onShortcutRecorded = { combo in
                recordedKeyCombo = combo
            }
            coordinator.shortcutService.startRecording()
        }
    }
}

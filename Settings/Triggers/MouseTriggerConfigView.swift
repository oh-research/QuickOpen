import SwiftUI

/// Configures a mouse-click trigger: modifier keys + click type.
struct MouseTriggerConfigView: View {
    @Binding var modifiers: Set<ModifierKey>
    @Binding var clickType: ClickType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ModifierKeysToggle(modifiers: $modifiers)

            Picker("Click Type:", selection: $clickType) {
                ForEach(ClickType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            if modifiers.isEmpty {
                Label("At least one modifier key is required", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            if modifiers == [.command] && clickType == .singleClick {
                Label("Cmd+Click conflicts with Finder multi-select", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .padding(8)
    }
}

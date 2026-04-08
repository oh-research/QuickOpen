import SwiftUI

/// Configures a trackpad-gesture trigger: modifier keys + gesture type.
struct TrackpadTriggerConfigView: View {
    @Binding var modifiers: Set<ModifierKey>
    @Binding var gestureType: TrackpadGestureType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ModifierKeysToggle(modifiers: $modifiers)

            Picker("Gesture Type:", selection: $gestureType) {
                ForEach(TrackpadGestureType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            if modifiers.isEmpty {
                Label("At least one modifier key is required", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            if gestureType == .forceClick {
                Label("Force Click requires a Force Touch trackpad", systemImage: "info.circle")
                    .foregroundStyle(.blue)
                    .font(.caption)
            }
        }
        .padding(8)
    }
}

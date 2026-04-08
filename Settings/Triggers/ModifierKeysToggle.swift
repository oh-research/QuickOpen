import SwiftUI

/// Reusable row of checkboxes for selecting modifier keys.
/// Shared between mouse and trackpad trigger configuration.
struct ModifierKeysToggle: View {
    @Binding var modifiers: Set<ModifierKey>

    var body: some View {
        HStack(spacing: 16) {
            Text("Modifier Keys:")
            ForEach(ModifierKey.allCases) { key in
                Toggle(isOn: binding(for: key)) {
                    Text("\(key.symbol) \(key.displayName)")
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    private func binding(for key: ModifierKey) -> Binding<Bool> {
        Binding(
            get: { modifiers.contains(key) },
            set: { isOn in
                if isOn {
                    modifiers.insert(key)
                } else {
                    modifiers.remove(key)
                }
            }
        )
    }
}

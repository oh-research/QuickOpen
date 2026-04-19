import AppKit
import SwiftUI

struct MappingListView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selectedMappingID: UUID?
    @State private var showingAddSheet = false
    @State private var editingMapping: TriggerMapping?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if coordinator.configManager.mappings.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            MappingDetailView(mode: .add) { newMapping in
                coordinator.configManager.addMapping(newMapping)
                coordinator.refreshTriggers()
            }
            .environment(coordinator)
        }
        .sheet(item: $editingMapping) { mapping in
            MappingDetailView(mode: .edit(mapping)) { updatedMapping in
                coordinator.configManager.updateMapping(updatedMapping)
                coordinator.refreshTriggers()
            }
            .environment(coordinator)
        }
    }

    // MARK: - Top toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            Text("Trigger Mappings")
                .font(.headline)

            Spacer()

            toolbarButton(
                systemImage: "plus",
                help: "Add new trigger mapping"
            ) {
                showingAddSheet = true
            }

            toolbarButton(
                systemImage: "minus",
                help: "Remove selected mapping",
                disabled: selectedMappingID == nil
            ) {
                if let id = selectedMappingID {
                    coordinator.configManager.removeMapping(id: id)
                    coordinator.refreshTriggers()
                    selectedMappingID = nil
                }
            }

            toolbarButton(
                systemImage: "pencil",
                help: "Edit selected mapping",
                disabled: selectedMappingID == nil
            ) {
                if let id = selectedMappingID,
                   let mapping = coordinator.configManager.mappings.first(where: { $0.id == id }) {
                    editingMapping = mapping
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// Standardized toolbar button. `.focusable(false)` removes the blue
    /// focus ring so the Settings window doesn't open with `+` selected
    /// as the default action target.
    private func toolbarButton(
        systemImage: String,
        help: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .focusable(false)
        .disabled(disabled)
        .help(help)
    }

    // MARK: - List

    private var list: some View {
        List(selection: $selectedMappingID) {
            ForEach(coordinator.configManager.mappings) { mapping in
                MappingRowView(mapping: mapping) {
                    coordinator.configManager.toggleMapping(id: mapping.id)
                    coordinator.refreshTriggers()
                }
                .tag(mapping.id)
                .onTapGesture(count: 2) {
                    editingMapping = mapping
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("No Trigger Mappings")
                    .font(.headline)
                Text("Add your first trigger to start opening files with your favorite apps.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            Button {
                showingAddSheet = true
            } label: {
                Label("New Trigger", systemImage: "plus")
            }
            .controlSize(.regular)
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Row

fileprivate struct MappingRowView: View {
    let mapping: TriggerMapping
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            appIcon
                .frame(width: 28, height: 28)
                .opacity(mapping.isEnabled ? 1.0 : 0.45)

            VStack(alignment: .leading, spacing: 2) {
                Text(mapping.name)
                    .fontWeight(.medium)
                    .foregroundStyle(mapping.isEnabled ? .primary : .secondary)

                Text(appName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TriggerBadgeView(trigger: mapping.trigger)
                .opacity(mapping.isEnabled ? 1.0 : 0.45)

            Toggle("", isOn: Binding(
                get: { mapping.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mapping.targetAppBundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.tertiary)
                .padding(2)
        }
    }

    private var appName: String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mapping.targetAppBundleID) {
            return url.deletingPathExtension().lastPathComponent
        }
        return mapping.targetAppBundleID
    }
}

// MARK: - Trigger chips

fileprivate struct TriggerBadgeView: View {
    let trigger: TriggerType

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                ChipLabel(text: chip)
            }
        }
    }

    private var chips: [String] {
        switch trigger {
        case .keyboard(let keyCombo):
            return keyCombo.chips
        case .mouseClick(let modifiers, let clickType):
            return sortedModifierSymbols(modifiers) + [clickType.chipLabel]
        case .trackpadGesture(let modifiers, let gestureType):
            return sortedModifierSymbols(modifiers) + [gestureType.chipLabel]
        }
    }

    private func sortedModifierSymbols(_ modifiers: Set<ModifierKey>) -> [String] {
        modifiers.sorted(by: { $0.rawValue < $1.rawValue }).map(\.symbol)
    }
}

fileprivate struct ChipLabel: View {
    let text: String

    var body: some View {
        // Hierarchical fill (.quaternary / .tertiary) inverts with the
        // enclosing List row's selection state, so the chip stays visible
        // against both the default background and the accent selection fill.
        // A fixed NSColor would disappear when the row is selected because
        // SwiftUI promotes `.primary` text to white in that state.
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.quaternary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(.tertiary, lineWidth: 0.5)
            )
    }
}

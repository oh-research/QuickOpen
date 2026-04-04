import SwiftUI

struct MappingListView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedMappingID: UUID?
    @State private var showingAddSheet = false
    @State private var editingMapping: TriggerMapping?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Trigger Mappings")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            // List
            List(selection: $selectedMappingID) {
                ForEach(appState.configManager.mappings) { mapping in
                    MappingRow(mapping: mapping) {
                        appState.configManager.toggleMapping(id: mapping.id)
                        appState.refreshTriggers()
                    }
                    .tag(mapping.id)
                    .onTapGesture(count: 2) {
                        editingMapping = mapping
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            // Toolbar
            HStack(spacing: 6) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .help("Add new trigger mapping")

                Button {
                    if let id = selectedMappingID {
                        appState.configManager.removeMapping(id: id)
                        appState.refreshTriggers()
                        selectedMappingID = nil
                    }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 28)
                }
                .disabled(selectedMappingID == nil)
                .help("Remove selected mapping")

                Spacer()

                Button {
                    if let id = selectedMappingID,
                       let mapping = appState.configManager.mappings.first(where: { $0.id == id }) {
                        editingMapping = mapping
                    }
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 28, height: 28)
                }
                .disabled(selectedMappingID == nil)
                .help("Edit selected mapping")
            }
            .padding(8)
            .background(.bar)
        }
        .sheet(isPresented: $showingAddSheet) {
            MappingDetailView(mode: .add) { newMapping in
                appState.configManager.addMapping(newMapping)
                appState.refreshTriggers()
            }
            .environment(appState)
        }
        .sheet(item: $editingMapping) { mapping in
            MappingDetailView(mode: .edit(mapping)) { updatedMapping in
                appState.configManager.updateMapping(updatedMapping)
                appState.refreshTriggers()
            }
            .environment(appState)
        }
    }
}

// MARK: - Mapping Row

struct MappingRow: View {
    let mapping: TriggerMapping
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Image(systemName: mapping.trigger.icon)
                .frame(width: 24)
                .foregroundStyle(mapping.isEnabled ? .primary : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(mapping.name)
                    .fontWeight(.medium)
                    .foregroundStyle(mapping.isEnabled ? .primary : .secondary)

                Text(appNameFromBundleID(mapping.targetAppBundleID))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(mapping.trigger.shortDescription)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Toggle("", isOn: Binding(
                get: { mapping.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private func appNameFromBundleID(_ bundleID: String) -> String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return appURL.deletingPathExtension().lastPathComponent
        }
        return bundleID
    }
}

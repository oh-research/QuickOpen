import SwiftUI

struct MappingDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case add
        case edit(TriggerMapping)
    }

    let mode: Mode
    let onSave: (TriggerMapping) -> Void

    @State private var name = ""
    @State private var triggerTypeSelection = 0 // 0=keyboard, 1=mouse, 2=trackpad
    @State private var targetAppBundleID = ""
    @State private var actionType: TriggerMapping.ActionType = .openFile
    @State private var fileExtensionFilter = ""

    // Keyboard shortcut state
    @State private var recordedKeyCombo: ShortcutService.KeyCombo?

    // Mouse click state
    @State private var mouseModifiers: Set<ModifierKey> = [.command]
    @State private var clickType: ClickType = .doubleClick

    // Trackpad gesture state
    @State private var trackpadModifiers: Set<ModifierKey> = [.command]
    @State private var gestureType: TrackpadGestureType = .forceClick

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    init(mode: Mode, onSave: @escaping (TriggerMapping) -> Void) {
        self.mode = mode
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text(isEditing ? "Edit Trigger Mapping" : "New Trigger Mapping")
                .font(.headline)
                .padding()

            Form {
                // Name
                TextField("Name:", text: $name)
                    .textFieldStyle(.roundedBorder)

                // Trigger type picker
                Picker("Trigger Type:", selection: $triggerTypeSelection) {
                    Text("Keyboard Shortcut").tag(0)
                    Text("Mouse Click").tag(1)
                    Text("Trackpad Gesture").tag(2)
                }
                .pickerStyle(.radioGroup)

                // Trigger-specific configuration
                GroupBox("Trigger Configuration") {
                    switch triggerTypeSelection {
                    case 0:
                        keyboardConfigPanel
                    case 1:
                        mouseConfigPanel
                    case 2:
                        trackpadConfigPanel
                    default:
                        EmptyView()
                    }
                }

                // Target app
                HStack {
                    TextField("Target App Bundle ID:", text: $targetAppBundleID)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        browseForApp()
                    }
                }

                if !targetAppBundleID.isEmpty {
                    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: targetAppBundleID) {
                        HStack {
                            if let icon = NSWorkspace.shared.icon(forFile: appURL.path) as NSImage? {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            Text(appURL.deletingPathExtension().lastPathComponent)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("App not found")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                // Action type
                Picker("Action:", selection: $actionType) {
                    ForEach(TriggerMapping.ActionType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.radioGroup)

                // File extension filter
                TextField("File Extension Filter (comma-separated, optional):", text: $fileExtensionFilter)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveMapping()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || targetAppBundleID.isEmpty || (triggerTypeSelection == 0 && recordedKeyCombo == nil))
            }
            .padding()
        }
        .frame(width: 930, height: 580)
        .onAppear {
            loadFromMode()
        }
    }

    // MARK: - Config Panels

    private var keyboardConfigPanel: some View {
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

                Button(appState.shortcutService.isRecording ? "Cancel" : "Record Shortcut") {
                    if appState.shortcutService.isRecording {
                        appState.shortcutService.stopRecording()
                    } else {
                        appState.shortcutService.onShortcutRecorded = { combo in
                            recordedKeyCombo = combo
                        }
                        appState.shortcutService.startRecording()
                    }
                }
            }

            if appState.shortcutService.isRecording {
                Text("Press a key combination...")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .padding(8)
    }

    private var mouseConfigPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            modifierCheckboxes(modifiers: $mouseModifiers)

            Picker("Click Type:", selection: $clickType) {
                ForEach(ClickType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            if mouseModifiers.isEmpty {
                Label("At least one modifier key is required", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            if mouseModifiers == [.command] && clickType == .singleClick {
                Label("Cmd+Click conflicts with Finder multi-select", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .padding(8)
    }

    private var trackpadConfigPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            modifierCheckboxes(modifiers: $trackpadModifiers)

            Picker("Gesture Type:", selection: $gestureType) {
                ForEach(TrackpadGestureType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            if trackpadModifiers.isEmpty {
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

    private func modifierCheckboxes(modifiers: Binding<Set<ModifierKey>>) -> some View {
        HStack(spacing: 16) {
            Text("Modifier Keys:")
            ForEach(ModifierKey.allCases) { key in
                Toggle(isOn: Binding(
                    get: { modifiers.wrappedValue.contains(key) },
                    set: { isOn in
                        if isOn {
                            modifiers.wrappedValue.insert(key)
                        } else {
                            modifiers.wrappedValue.remove(key)
                        }
                    }
                )) {
                    Text("\(key.symbol) \(key.displayName)")
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    // MARK: - Actions

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier {
                targetAppBundleID = bundleID
            }
        }
    }

    private func saveMapping() {
        let trigger: TriggerType
        switch triggerTypeSelection {
        case 0:
            trigger = .keyboard(keyCombo: recordedKeyCombo!)
        case 1:
            trigger = .mouseClick(modifiers: mouseModifiers, clickType: clickType)
        case 2:
            trigger = .trackpadGesture(modifiers: trackpadModifiers, gestureType: gestureType)
        default:
            return
        }

        let parsedExtensions: [String] = fileExtensionFilter.isEmpty ? [] :
            fileExtensionFilter.split(separator: ",")
                .map {
                    var ext = $0.trimmingCharacters(in: .whitespaces).lowercased()
                    if ext.hasPrefix(".") { ext = String(ext.dropFirst()) }
                    return ext
                }
                .filter { !$0.isEmpty }
        let extensions: [String]? = parsedExtensions.isEmpty ? nil : parsedExtensions

        let id: UUID
        if case .edit(let existing) = mode {
            id = existing.id
        } else {
            id = UUID()
        }

        let mapping = TriggerMapping(
            id: id,
            name: name,
            trigger: trigger,
            targetAppBundleID: targetAppBundleID,
            actionType: actionType,
            fileExtensionFilter: extensions,
            isEnabled: true
        )

        onSave(mapping)
    }

    private func loadFromMode() {
        guard case .edit(let mapping) = mode else { return }

        name = mapping.name
        targetAppBundleID = mapping.targetAppBundleID
        actionType = mapping.actionType
        fileExtensionFilter = mapping.fileExtensionFilter?.joined(separator: ", ") ?? ""

        switch mapping.trigger {
        case .keyboard(let keyCombo):
            triggerTypeSelection = 0
            recordedKeyCombo = keyCombo
        case .mouseClick(let mods, let click):
            triggerTypeSelection = 1
            mouseModifiers = mods
            clickType = click
        case .trackpadGesture(let mods, let gesture):
            triggerTypeSelection = 2
            trackpadModifiers = mods
            gestureType = gesture
        }
    }
}

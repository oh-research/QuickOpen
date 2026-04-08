import Carbon
import Cocoa
import Observation
import os

/// Manages global keyboard shortcut registration and detection using Carbon Hot Key API.
@Observable
final class ShortcutService {
    private static let logger = Logger(subsystem: "com.ohresearch.QuickOpen", category: "ShortcutService")

    private var hotKeyRefs: [String: EventHotKeyRef] = [:]
    private var hotKeyHandlers: [UInt32: () -> Void] = [:]
    private var shortcutToHotKeyID: [String: UInt32] = [:]
    private var nextHotKeyID: UInt32 = 1
    private var eventHandler: EventHandlerRef?
    private let hotKeyHandlersLock = NSLock()

    /// Currently recording shortcut info
    private(set) var isRecording = false
    private var recordingMonitor: Any?
    var onShortcutRecorded: ((KeyCombo) -> Void)?

    struct KeyCombo: Codable, Hashable {
        let keyCode: UInt32
        let modifiers: UInt32

        var displayString: String {
            var parts: [String] = []
            if modifiers & UInt32(controlKey) != 0 { parts.append("\u{2303}") }
            if modifiers & UInt32(optionKey) != 0 { parts.append("\u{2325}") }
            if modifiers & UInt32(shiftKey) != 0 { parts.append("\u{21E7}") }
            if modifiers & UInt32(cmdKey) != 0 { parts.append("\u{2318}") }
            parts.append(keyCodeToString(keyCode))
            return parts.joined()
        }
    }

    init() {
        installEventHandler()
    }

    deinit {
        unregisterAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    func register(shortcutID: String, keyCombo: KeyCombo, handler: @escaping () -> Void) {
        unregister(shortcutID: shortcutID)

        let hotKeyID = EventHotKeyID(signature: OSType(0x514F_504E), // "QOPN"
                                      id: nextHotKeyID)

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCombo.keyCode,
            keyCombo.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs[shortcutID] = ref
            hotKeyHandlersLock.lock()
            hotKeyHandlers[nextHotKeyID] = handler
            hotKeyHandlersLock.unlock()
            shortcutToHotKeyID[shortcutID] = nextHotKeyID
            nextHotKeyID += 1
            Self.logger.info("Registered hotkey: \(shortcutID)")
        } else {
            Self.logger.error("Failed to register hotkey: \(shortcutID), status: \(status)")
        }
    }

    func unregister(shortcutID: String) {
        if let ref = hotKeyRefs.removeValue(forKey: shortcutID) {
            UnregisterEventHotKey(ref)
            if let hotKeyID = shortcutToHotKeyID.removeValue(forKey: shortcutID) {
                hotKeyHandlersLock.lock()
                hotKeyHandlers.removeValue(forKey: hotKeyID)
                hotKeyHandlersLock.unlock()
            }
            Self.logger.info("Unregistered hotkey: \(shortcutID)")
        }
    }

    func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        shortcutToHotKeyID.removeAll()
        hotKeyHandlersLock.lock()
        hotKeyHandlers.removeAll()
        hotKeyHandlersLock.unlock()
    }

    // MARK: - Recording

    func startRecording() {
        isRecording = true
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }

            let modifiers = self.nsEventModifiersToCarbonModifiers(event.modifierFlags)
            let keyCombo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)

            self.isRecording = false
            if let monitor = self.recordingMonitor {
                NSEvent.removeMonitor(monitor)
                self.recordingMonitor = nil
            }

            self.onShortcutRecorded?(keyCombo)
            return nil // consume the event
        }
    }

    func stopRecording() {
        isRecording = false
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
            recordingMonitor = nil
        }
    }

    // MARK: - Private

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let handlerRef = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData, let event else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<ShortcutService>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                GetEventParameter(event,
                                  EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID),
                                  nil,
                                  MemoryLayout<EventHotKeyID>.size,
                                  nil,
                                  &hotKeyID)

                service.hotKeyHandlersLock.lock()
                let handler = service.hotKeyHandlers[hotKeyID.id]
                service.hotKeyHandlersLock.unlock()
                if let handler {
                    DispatchQueue.main.async { handler() }
                }

                return noErr
            },
            1,
            &eventType,
            handlerRef,
            &eventHandler
        )
    }

    private func nsEventModifiersToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonMods: UInt32 = 0
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        return carbonMods
    }
}

// MARK: - Key Code to String

private func keyCodeToString(_ keyCode: UInt32) -> String {
    let keyMap: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
        50: "`", 51: "Delete", 53: "Esc",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 109: "F10", 111: "F12", 103: "F11",
        118: "F4", 120: "F2", 122: "F1",
        123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
    ]
    return keyMap[keyCode] ?? "Key\(keyCode)"
}

import CoreGraphics
import Foundation

// MARK: - Enums

enum ModifierKey: String, Codable, CaseIterable, Hashable, Identifiable {
    case command, option, control, shift

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .command: return "\u{2318}"
        case .option: return "\u{2325}"
        case .control: return "\u{2303}"
        case .shift: return "\u{21E7}"
        }
    }

    var displayName: String {
        switch self {
        case .command: return "Cmd"
        case .option: return "Option"
        case .control: return "Control"
        case .shift: return "Shift"
        }
    }

    var cgEventFlag: CGEventFlags {
        switch self {
        case .command: return .maskCommand
        case .option: return .maskAlternate
        case .control: return .maskControl
        case .shift: return .maskShift
        }
    }
}

enum ClickType: String, Codable, CaseIterable {
    case singleClick, doubleClick, rightClick

    var displayName: String {
        switch self {
        case .singleClick: return "Single Click"
        case .doubleClick: return "Double Click"
        case .rightClick: return "Right Click"
        }
    }
}

enum TrackpadGestureType: String, Codable, CaseIterable {
    case forceClick
    case twoFingerTap

    var displayName: String {
        switch self {
        case .forceClick: return "Force Click"
        case .twoFingerTap: return "Two Finger Tap"
        }
    }
}

// MARK: - Trigger Type

enum TriggerType: Codable, Hashable {
    case keyboard(keyCombo: ShortcutService.KeyCombo)
    case mouseClick(modifiers: Set<ModifierKey>, clickType: ClickType)
    case trackpadGesture(modifiers: Set<ModifierKey>, gestureType: TrackpadGestureType)

    var displayName: String {
        switch self {
        case .keyboard:
            return "Keyboard Shortcut"
        case .mouseClick:
            return "Mouse Click"
        case .trackpadGesture:
            return "Trackpad Gesture"
        }
    }

    var icon: String {
        switch self {
        case .keyboard: return "keyboard"
        case .mouseClick: return "computermouse"
        case .trackpadGesture: return "hand.point.up"
        }
    }

    var shortDescription: String {
        switch self {
        case .keyboard(let keyCombo):
            return keyCombo.displayString
        case .mouseClick(let modifiers, let clickType):
            let modStr = modifiers.sorted(by: { $0.rawValue < $1.rawValue })
                .map(\.symbol).joined()
            return "\(modStr)+\(clickType.displayName)"
        case .trackpadGesture(let modifiers, let gestureType):
            let modStr = modifiers.sorted(by: { $0.rawValue < $1.rawValue })
                .map(\.symbol).joined()
            return "\(modStr)+\(gestureType.displayName)"
        }
    }
}

// MARK: - Trigger Mapping

struct TriggerMapping: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var trigger: TriggerType
    var targetAppBundleID: String
    var actionType: ActionType
    var fileExtensionFilter: [String]?
    var isEnabled: Bool

    enum ActionType: String, Codable, CaseIterable {
        case openFile
        case openAtLocation

        var displayName: String {
            switch self {
            case .openFile: return "Open selected file with app"
            case .openAtLocation: return "Open app at current Finder location"
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        trigger: TriggerType,
        targetAppBundleID: String,
        actionType: ActionType,
        fileExtensionFilter: [String]? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.targetAppBundleID = targetAppBundleID
        self.actionType = actionType
        self.fileExtensionFilter = fileExtensionFilter
        self.isEnabled = isEnabled
    }
}

// MARK: - Config Container

struct AppConfig: Codable {
    var version: Int = 1
    var mappings: [TriggerMapping]

    init(mappings: [TriggerMapping] = []) {
        self.mappings = mappings
    }
}

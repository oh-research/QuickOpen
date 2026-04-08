import Foundation

struct TriggerMatcher {
    /// Finds the first enabled mapping that matches the given trigger, optionally filtering by file extension.
    static func match(
        trigger: TriggerType,
        mappings: [TriggerMapping],
        fileExtension: String? = nil
    ) -> TriggerMapping? {
        mappings.first { mapping in
            guard mapping.isEnabled else { return false }
            guard mapping.trigger == trigger else { return false }

            // Check file extension filter if present
            if let filter = mapping.fileExtensionFilter, !filter.isEmpty,
               let ext = fileExtension {
                return filter.contains(ext.lowercased())
            }

            return true
        }
    }

    /// Finds all enabled mappings that match the given trigger.
    static func matchAll(
        trigger: TriggerType,
        mappings: [TriggerMapping],
        fileExtension: String? = nil
    ) -> [TriggerMapping] {
        mappings.filter { mapping in
            guard mapping.isEnabled else { return false }
            guard mapping.trigger == trigger else { return false }

            if let filter = mapping.fileExtensionFilter, !filter.isEmpty,
               let ext = fileExtension {
                return filter.contains(ext.lowercased())
            }

            return true
        }
    }

    /// Builds a TriggerType from mouse event parameters.
    static func mouseTrigger(modifiers: Set<ModifierKey>, clickType: ClickType) -> TriggerType {
        .mouseClick(modifiers: modifiers, clickType: clickType)
    }

    /// Builds a TriggerType from trackpad gesture parameters.
    static func trackpadTrigger(modifiers: Set<ModifierKey>, gestureType: TrackpadGestureType) -> TriggerType {
        .trackpadGesture(modifiers: modifiers, gestureType: gestureType)
    }
}

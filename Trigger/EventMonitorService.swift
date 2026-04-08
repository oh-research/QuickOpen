import Cocoa
import Observation
import os

/// Monitors global mouse and trackpad events for trigger detection.
@Observable
final class EventMonitorService {
    private static let logger = Logger(subsystem: "com.ohresearch.QuickOpen", category: "EventMonitorService")

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressureMonitor: Any?
    private(set) var isActive = false
    private var isHandlingPermissionLoss = false

    /// Called when a mouse/trackpad trigger is detected.
    /// The second parameter is a completion callback that MUST be called when handling is done.
    var onTriggerDetected: ((TriggerType, @escaping () -> Void) -> Void)?

    /// Called when the event tap detects that accessibility permission was lost.
    var onPermissionLost: (() -> Void)?

    /// Tracks double-click timing
    private var lastClickTime: TimeInterval = 0
    private var lastClickLocation: CGPoint = .zero
    private var lastClickModifiers: Set<ModifierKey> = []
    private static let doubleClickInterval: TimeInterval = 0.5
    private static let doubleClickRadius: CGFloat = 5.0

    /// Processing flag to prevent re-entrant trigger execution
    private var isProcessingTrigger = false

    /// Pending single-click timer for deferred single-click dispatch
    private var pendingSingleClickTimer: DispatchWorkItem?
    private var pendingSingleClickTrigger: TriggerType?

    /// Run loop on which the event tap source was installed (Fix 3)
    private var installedRunLoop: CFRunLoop?

    /// Lock protecting all mutable state accessed from multiple threads.
    /// The CGEventTap callback runs on an arbitrary thread; handlePressureEvent
    /// runs on the main thread. stateLock serialises all accesses.
    private let stateLock = NSLock()

    deinit {
        stop()
    }

    func start() {
        // Fix 4: Lock before reading/writing isActive to prevent concurrent starts.
        stateLock.lock()
        guard !isActive else {
            stateLock.unlock()
            return
        }
        isActive = true  // Set immediately to block any concurrent call past the guard.
        isHandlingPermissionLoss = false
        stateLock.unlock()

        // CGEventTap for mouse clicks
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
            guard let userInfo else { return Unmanaged.passRetained(event) }
            let service = Unmanaged<EventMonitorService>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                // Only re-enable if we still have accessibility permission.
                // If permission was revoked, re-enabling would fight the system
                // and can freeze all input devices.
                if AXIsProcessTrusted(), let tap = service.activeEventTap() {
                    CGEvent.tapEnable(tap: tap, enable: true)
                } else {
                    service.schedulePermissionLossHandling(
                        reason: "Event tap disabled after accessibility permission was removed"
                    )
                }
                return Unmanaged.passRetained(event)
            }

            return service.handleEvent(proxy: proxy, type: type, event: event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        )

        guard let tap = eventTap else {
            Self.logger.error("Failed to create event tap. Accessibility permission required.")
            // Fix 4: Roll back isActive so callers can retry.
            stateLock.lock()
            isActive = false
            stateLock.unlock()
            return
        }

        // Fix 3: Always use the main run loop so start() and stop() operate on
        // the same CFRunLoop regardless of which thread called each method.
        let runLoop = CFRunLoopGetMain()
        installedRunLoop = runLoop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(runLoop, runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // NSEvent global monitor for pressure (Force Touch) events
        pressureMonitor = NSEvent.addGlobalMonitorForEvents(matching: .pressure) { [weak self] event in
            self?.handlePressureEvent(event)
        }

        Self.logger.info("Event monitor started")
    }

    func stop() {
        // Fix 4: Serialise the isActive transition under the lock.
        stateLock.lock()
        guard isActive else {
            stateLock.unlock()
            return
        }
        isActive = false
        isHandlingPermissionLoss = false
        let tap = eventTap
        let source = runLoopSource
        let runLoop = installedRunLoop
        let monitor = pressureMonitor
        let pendingTimer = pendingSingleClickTimer
        eventTap = nil
        runLoopSource = nil
        installedRunLoop = nil
        pressureMonitor = nil
        pendingSingleClickTimer = nil
        pendingSingleClickTrigger = nil
        lastClickTime = 0
        lastClickLocation = .zero
        lastClickModifiers = []
        isProcessingTrigger = false
        stateLock.unlock()

        pendingTimer?.cancel()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        // Fix 3: Use the run loop that was captured in start(), not the current one.
        if let source, let runLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
        }
        if let source {
            CFRunLoopSourceInvalidate(source)
        }
        if let tap {
            CFMachPortInvalidate(tap)
        }
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        Self.logger.info("Event monitor stopped")
    }

    // MARK: - Pressure (Force Touch) Handling

    private func handlePressureEvent(_ event: NSEvent) {
        guard FinderService.isFinderFrontmost else { return }

        stateLock.lock()
        let processing = isProcessingTrigger
        stateLock.unlock()
        guard !processing else { return }

        // Stage 2 = force click threshold reached
        guard event.stage >= 2 else { return }

        let modifiers = extractModifiers(from: event)
        guard !modifiers.isEmpty else { return }

        let trigger = TriggerType.trackpadGesture(modifiers: modifiers, gestureType: .forceClick)
        fireTrigger(trigger)
    }

    // MARK: - CGEvent Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard FinderService.isFinderFrontmost else {
            return Unmanaged.passRetained(event)
        }

        stateLock.lock()
        let processing = isProcessingTrigger
        stateLock.unlock()
        guard !processing else {
            return Unmanaged.passRetained(event)
        }

        let modifiers = extractModifiers(from: event)
        guard !modifiers.isEmpty else {
            if type == .leftMouseDown {
                stateLock.lock()
                lastClickTime = ProcessInfo.processInfo.systemUptime
                lastClickLocation = event.location
                // Fix 1: A plain (modifier-less) click resets the stored modifiers so
                // a subsequent modifier click cannot accidentally pair with stale state.
                lastClickModifiers = []
                stateLock.unlock()
            }
            return Unmanaged.passRetained(event)
        }

        switch type {
        case .leftMouseDown:
            let now = ProcessInfo.processInfo.systemUptime
            let location = event.location

            stateLock.lock()
            let timeDelta = now - lastClickTime
            let distance = hypot(location.x - lastClickLocation.x, location.y - lastClickLocation.y)
            stateLock.unlock()

            if timeDelta < Self.doubleClickInterval && distance < Self.doubleClickRadius {
                // Second click within interval: cancel pending single-click and fire double-click.
                // Fix 1: Use the modifiers captured during the FIRST click, not the current ones.
                stateLock.lock()
                let timerToCancel = pendingSingleClickTimer
                pendingSingleClickTimer = nil
                pendingSingleClickTrigger = nil
                lastClickTime = 0
                let firstClickModifiers = lastClickModifiers  // Fix 1: read first-click modifiers
                lastClickModifiers = []
                stateLock.unlock()

                // DispatchWorkItem.cancel() is thread-safe; call outside the lock
                timerToCancel?.cancel()

                let trigger = TriggerType.mouseClick(modifiers: firstClickModifiers, clickType: .doubleClick)
                fireTrigger(trigger)
                return nil // suppress the event
            } else {
                // First click with modifiers: record time/location/modifiers, pass event through,
                // and schedule a deferred single-click trigger.
                stateLock.lock()
                lastClickTime = now
                lastClickLocation = location
                lastClickModifiers = modifiers  // Fix 1: snapshot modifiers for the double-click branch
                stateLock.unlock()

                let singleClickTrigger = TriggerType.mouseClick(modifiers: modifiers, clickType: .singleClick)

                let workItem = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.stateLock.lock()
                    let stillPending = self.pendingSingleClickTrigger != nil
                    if stillPending {
                        self.pendingSingleClickTrigger = nil
                    }
                    self.stateLock.unlock()
                    guard stillPending else { return }
                    self.fireTrigger(singleClickTrigger)
                }

                stateLock.lock()
                let oldTimer = pendingSingleClickTimer
                pendingSingleClickTimer = workItem
                pendingSingleClickTrigger = singleClickTrigger
                stateLock.unlock()

                // Cancel outside the lock; DispatchWorkItem.cancel() is thread-safe
                oldTimer?.cancel()

                DispatchQueue.main.asyncAfter(deadline: .now() + Self.doubleClickInterval, execute: workItem)

                // Pass the event through so Finder can perform normal selection
                return Unmanaged.passRetained(event)
            }

        case .rightMouseDown:
            let trigger = TriggerType.mouseClick(modifiers: modifiers, clickType: .rightClick)
            fireTrigger(trigger)
            return nil

        default:
            break
        }

        return Unmanaged.passRetained(event)
    }

    private func extractModifiers(from event: CGEvent) -> Set<ModifierKey> {
        let flags = event.flags
        var modifiers = Set<ModifierKey>()
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        return modifiers
    }

    private func extractModifiers(from event: NSEvent) -> Set<ModifierKey> {
        let flags = event.modifierFlags
        var modifiers = Set<ModifierKey>()
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }

    private func fireTrigger(_ trigger: TriggerType) {
        stateLock.lock()
        guard !isProcessingTrigger else {
            stateLock.unlock()
            return
        }
        isProcessingTrigger = true
        stateLock.unlock()

        // Fix 2: The caller signals completion by invoking the callback, which clears
        // isProcessingTrigger. A 5-second safety timeout handles callers that never call
        // completion (prevents permanent suppression of all future triggers).
        let completion: () -> Void = { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            self.isProcessingTrigger = false
            self.stateLock.unlock()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { completion(); return }
            if let handler = self.onTriggerDetected {
                handler(trigger, completion)
            } else {
                // No handler registered — release the lock immediately.
                completion()
            }
        }

        // Safety net: if the caller never invokes completion, reset after 5 seconds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            let stillBlocked = self.isProcessingTrigger
            if stillBlocked {
                self.isProcessingTrigger = false
            }
            self.stateLock.unlock()
            if stillBlocked {
                EventMonitorService.logger.warning("Trigger completion was never called — released isProcessingTrigger via safety timeout")
            }
        }
    }

    private func activeEventTap() -> CFMachPort? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard isActive else { return nil }
        return eventTap
    }

    private func schedulePermissionLossHandling(reason: String) {
        stateLock.lock()
        let shouldHandle = isActive && !isHandlingPermissionLoss
        if shouldHandle {
            isHandlingPermissionLoss = true
        }
        stateLock.unlock()

        guard shouldHandle else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            Self.logger.warning("\(reason, privacy: .public)")
            self.stop()
            self.onPermissionLost?()
        }
    }
}

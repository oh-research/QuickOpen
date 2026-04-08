import AppKit
import os

// MARK: - FinderError

enum FinderError: Error {
    case finderNotRunning
    case permissionDenied
    case timeout
    case noSelection
    case unknown(String)

    var localizedDescription: String {
        switch self {
        case .finderNotRunning:
            return "Finder is not running"
        case .permissionDenied:
            return "Automation permission denied — please grant in System Settings"
        case .timeout:
            return "Finder request timed out"
        case .noSelection:
            return "No files selected in Finder"
        case .unknown(let message):
            return "Finder error: \(message)"
        }
    }
}

// MARK: - FinderService

final class FinderService {
    private static let logger = Logger(subsystem: "com.ohresearch.QuickOpen", category: "FinderService")
    private static let finderBundleID = "com.apple.finder"

    static var isFinderFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == finderBundleID
    }

    /// Returns URLs of currently selected items in Finder via AppleScript.
    static func getSelectedItems() async -> Result<[URL], FinderError> {
        let script = """
        tell application "Finder"
            set selectedItems to selection
            if (count of selectedItems) is 0 then
                return ""
            end if
            set pathList to ""
            repeat with anItem in selectedItems
                set pathList to pathList & (POSIX path of (anItem as alias)) & linefeed
            end repeat
            return pathList
        end tell
        """

        let result = await runAppleScript(script)
        switch result {
        case .success(let urls):
            if urls.isEmpty {
                return .failure(.noSelection)
            }
            return .success(urls)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Returns the URL of the current Finder window's directory.
    static func getCurrentDirectory() async -> Result<URL, FinderError> {
        let script = """
        tell application "Finder"
            if (count of Finder windows) is 0 then
                return POSIX path of (desktop as alias)
            end if
            return POSIX path of (target of front Finder window as alias)
        end tell
        """

        let result = await runAppleScript(script)
        switch result {
        case .success(let urls):
            if let first = urls.first {
                return .success(first)
            }
            // Empty output but no error — fall back to desktop
            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
            return .success(desktopURL)
        case .failure(let error):
            return .failure(error)
        }
    }

    private static func runAppleScript(_ source: String) async -> Result<[URL], FinderError> {
        do {
            return try await withThrowingTaskGroup(of: Result<[URL], FinderError>.self) { group in
                // Task 1: run the AppleScript on a background thread.
                group.addTask {
                    await withCheckedContinuation { continuation in
                        DispatchQueue.global(qos: .userInitiated).async {
                            var error: NSDictionary?
                            guard let appleScript = NSAppleScript(source: source) else {
                                logger.error("Failed to create AppleScript")
                                continuation.resume(returning: .failure(.unknown("Failed to create AppleScript object")))
                                return
                            }

                            let result = appleScript.executeAndReturnError(&error)

                            if let error = error {
                                logger.error("AppleScript error: \(error)")
                                let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
                                let finderError: FinderError
                                switch errorNumber {
                                case -600:
                                    finderError = .finderNotRunning
                                case -1743:
                                    finderError = .permissionDenied
                                default:
                                    let message = (error[NSAppleScript.errorMessage] as? String)
                                        ?? "Error code \(errorNumber)"
                                    finderError = .unknown(message)
                                }
                                continuation.resume(returning: .failure(finderError))
                                return
                            }

                            guard let output = result.stringValue else {
                                // No error and no string output means empty result (e.g. empty selection)
                                continuation.resume(returning: .success([]))
                                return
                            }

                            let urls = output
                                .split(separator: "\n")
                                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                                .map { URL(fileURLWithPath: $0) }

                            continuation.resume(returning: .success(urls))
                        }
                    }
                }

                // Task 2: 5-second timeout guard.
                group.addTask {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    return .failure(.timeout)
                }

                // Return whichever task finishes first, then cancel the other.
                let first = try await group.next()!
                group.cancelAll()
                return first
            }
        } catch {
            // Task.sleep throws CancellationError when the AppleScript task wins and
            // cancels the group, or any other unexpected thrown error — treat as timeout.
            return .failure(.timeout)
        }
    }
}

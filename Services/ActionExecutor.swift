import AppKit
import UserNotifications
import os

/// Orchestrates trigger detection → Finder query → app launch.
final class ActionExecutor {
    private static let logger = Logger(subsystem: "com.ohresearch.QuickOpen", category: "ActionExecutor")

    static let maxFilesToOpen = 20

    static func execute(mapping: TriggerMapping) async {
        do {
            switch mapping.actionType {
            case .openFile:
                try await executeOpenFile(mapping: mapping)
            case .openAtLocation:
                try await executeOpenAtLocation(mapping: mapping)
            }
        } catch {
            logger.error("Action execution failed: \(error.localizedDescription)")
            showErrorNotification(message: error.localizedDescription)
        }
    }

    private static func executeOpenFile(mapping: TriggerMapping) async throws {
        let result = await FinderService.getSelectedItems()

        let selectedItems: [URL]
        switch result {
        case .success(let urls):
            selectedItems = urls
        case .failure(let finderError):
            let message: String
            switch finderError {
            case .noSelection:
                message = "No files selected in Finder"
            case .finderNotRunning:
                message = "Finder is not running"
            case .permissionDenied:
                message = "Automation permission denied — please grant in System Settings"
            case .timeout:
                message = "Finder request timed out"
            case .unknown(let detail):
                message = "Finder error: \(detail)"
            }
            logger.warning("getSelectedItems failed: \(message)")
            showErrorNotification(message: message)
            return
        }

        // Apply file extension filter
        let filteredItems: [URL]
        if let filter = mapping.fileExtensionFilter, !filter.isEmpty {
            filteredItems = selectedItems.filter { url in
                filter.contains(url.pathExtension.lowercased())
            }
            guard !filteredItems.isEmpty else {
                logger.info("No selected files match extension filter: \(filter)")
                return
            }
        } else {
            filteredItems = selectedItems
        }

        // Limit to prevent accidentally opening too many files
        if filteredItems.count > maxFilesToOpen {
            logger.warning("Too many files selected (\(filteredItems.count)), limiting to \(maxFilesToOpen)")
            try await AppLaunchService.openFiles(Array(filteredItems.prefix(maxFilesToOpen)),
                                                  withBundleID: mapping.targetAppBundleID)
        } else {
            try await AppLaunchService.openFiles(filteredItems,
                                                  withBundleID: mapping.targetAppBundleID)
        }
    }

    private static func executeOpenAtLocation(mapping: TriggerMapping) async throws {
        let result = await FinderService.getCurrentDirectory()

        let directory: URL
        switch result {
        case .success(let url):
            directory = url
        case .failure(let finderError):
            let message: String
            switch finderError {
            case .finderNotRunning:
                message = "Finder is not running"
            case .permissionDenied:
                message = "Automation permission denied — please grant in System Settings"
            case .timeout:
                message = "Finder request timed out"
            case .noSelection:
                message = "Could not determine current Finder directory"
            case .unknown(let detail):
                message = "Finder error: \(detail)"
            }
            logger.warning("getCurrentDirectory failed: \(message)")
            showErrorNotification(message: message)
            return
        }

        try await AppLaunchService.openAtLocation(directory, withBundleID: mapping.targetAppBundleID)
    }

    private static func showErrorNotification(message: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "QuickOpen"
            content.body = message
            content.sound = .default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }
}

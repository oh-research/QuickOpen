import AppKit
import os

final class AppLaunchService {
    private static let logger = Logger(subsystem: "com.ohresearch.QuickOpen", category: "AppLaunchService")

    /// Opens files with the specified app (by bundle ID).
    static func openFiles(_ urls: [URL], withBundleID bundleID: String) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw LaunchError.appNotFound(bundleID)
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        try await NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: config)
        logger.info("Opened \(urls.count) file(s) with \(bundleID)")
    }

    /// Launches an app at a specific directory location using NSWorkspace.
    static func openAtLocation(_ directoryURL: URL, withBundleID bundleID: String) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw LaunchError.appNotFound(bundleID)
        }

        let path = directoryURL.path

        guard FileManager.default.fileExists(atPath: path) else {
            throw LaunchError.invalidPath(path)
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        try await NSWorkspace.shared.open([directoryURL], withApplicationAt: appURL, configuration: config)
        logger.info("Opened \(appURL.deletingPathExtension().lastPathComponent) at \(path)")
    }

    enum LaunchError: LocalizedError {
        case appNotFound(String)
        case invalidPath(String)
        case openCommandFailed(String)

        var errorDescription: String? {
            switch self {
            case .appNotFound(let bundleID):
                return "Application not found: \(bundleID)"
            case .invalidPath(let path):
                return "Path does not exist: \(path)"
            case .openCommandFailed(let detail):
                return "Failed to open app: \(detail)"
            }
        }
    }
}

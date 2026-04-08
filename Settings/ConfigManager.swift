import Foundation
import Observation
import os

@Observable
final class ConfigManager {
    private static let logger = Logger(subsystem: "com.ohresearch.QuickOpen", category: "ConfigManager")
    private static let currentVersion = 1

    private let configURL: URL
    private let configLock = NSRecursiveLock()
    private(set) var config: AppConfig

    var mappings: [TriggerMapping] {
        get {
            configLock.lock()
            defer { configLock.unlock() }
            return config.mappings
        }
        set {
            configLock.lock()
            defer { configLock.unlock() }
            config.mappings = newValue
            save()
        }
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let quickOpenDir = appSupport.appendingPathComponent("QuickOpen", isDirectory: true)

        if !FileManager.default.fileExists(atPath: quickOpenDir.path) {
            try? FileManager.default.createDirectory(at: quickOpenDir, withIntermediateDirectories: true)
        }

        self.configURL = quickOpenDir.appendingPathComponent("config.json")
        self.config = AppConfig()
        load()
    }

    func load() {
        configLock.lock()
        defer { configLock.unlock() }

        guard FileManager.default.fileExists(atPath: configURL.path) else {
            Self.logger.info("No config file found, using defaults")
            return
        }

        do {
            let data = try Data(contentsOf: configURL)
            var decoded = try JSONDecoder().decode(AppConfig.self, from: data)

            if decoded.version != Self.currentVersion {
                Self.logger.warning("Config version mismatch: found \(decoded.version), current is \(Self.currentVersion). Migrating.")
                decoded = migrate(from: decoded)
            }

            self.config = decoded
            Self.logger.info("Loaded \(decoded.mappings.count) mappings")
        } catch {
            Self.logger.error("Failed to load config: \(error.localizedDescription)")
        }
    }

    func save() {
        configLock.lock()
        defer { configLock.unlock() }

        // Always stamp the current version before writing.
        config.version = Self.currentVersion

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL, options: .atomic)
            Self.logger.info("Saved \(self.config.mappings.count) mappings")
        } catch {
            Self.logger.error("Failed to save config: \(error.localizedDescription)")
        }
    }

    // MARK: - Migration

    /// Migrates a decoded config from an older version to the current schema.
    /// Returns a config stamped with the current version.
    private func migrate(from old: AppConfig) -> AppConfig {
        // Currently at v1 — no structural changes needed yet.
        // Future migrations: add cases for older version numbers.
        Self.logger.info("Migration complete: v\(old.version) → v\(Self.currentVersion)")
        var migrated = old
        migrated.version = Self.currentVersion
        return migrated
    }

    // MARK: - Mutation helpers

    func addMapping(_ mapping: TriggerMapping) {
        configLock.lock()
        defer { configLock.unlock() }
        config.mappings.append(mapping)
        save()
    }

    func updateMapping(_ mapping: TriggerMapping) {
        configLock.lock()
        defer { configLock.unlock() }
        if let index = config.mappings.firstIndex(where: { $0.id == mapping.id }) {
            config.mappings[index] = mapping
            save()
        }
    }

    func removeMapping(id: UUID) {
        configLock.lock()
        defer { configLock.unlock() }
        config.mappings.removeAll { $0.id == id }
        save()
    }

    func toggleMapping(id: UUID) {
        configLock.lock()
        defer { configLock.unlock() }
        if let index = config.mappings.firstIndex(where: { $0.id == id }) {
            config.mappings[index].isEnabled.toggle()
            save()
        }
    }
}

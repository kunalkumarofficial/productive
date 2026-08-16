import Foundation

/// All data lives in a single JSON file under Application Support.
/// Writes are atomic, and a timestamped backup is taken once per launch
/// before the file is first overwritten. Nothing ever leaves the Mac.
enum Persistence {
    static let fileName = "productive-data.json"

    static var dataDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Productive", isDirectory: true)
    }

    static var dataFileURL: URL {
        dataDirectory.appendingPathComponent(fileName)
    }

    static var backupsDirectory: URL {
        dataDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func ensureDirectories() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
    }

    /// Returns nil when no data file exists yet (first launch).
    /// Throws when a file exists but cannot be read or decoded; in that case
    /// the unreadable file is preserved next to the data file so nothing is lost.
    static func load() throws -> AppData? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dataFileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: dataFileURL)
            return try makeDecoder().decode(AppData.self, from: data)
        } catch {
            let stamp = backupTimestamp()
            let quarantineURL = dataDirectory.appendingPathComponent("unreadable-\(stamp).json")
            try? fm.moveItem(at: dataFileURL, to: quarantineURL)
            throw error
        }
    }

    static func save(_ appData: AppData) throws {
        try ensureDirectories()
        let data = try makeEncoder().encode(appData)
        try data.write(to: dataFileURL, options: .atomic)
    }

    /// Copies the current data file into Backups/ with a timestamped name.
    static func backUpCurrentFile() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dataFileURL.path) else { return }
        do {
            try ensureDirectories()
            let destination = backupsDirectory.appendingPathComponent("backup-\(backupTimestamp()).json")
            if !fm.fileExists(atPath: destination.path) {
                try fm.copyItem(at: dataFileURL, to: destination)
            }
            pruneBackups(keep: 20)
        } catch {
            // Backups are best-effort; the primary save path still protects data.
        }
    }

    static func pruneBackups(keep: Int) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return }
        let sorted = entries
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        guard sorted.count > keep else { return }
        for url in sorted.dropFirst(keep) {
            try? fm.removeItem(at: url)
        }
    }

    private static func backupTimestamp() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.string(from: Date())
    }
}

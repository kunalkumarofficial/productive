import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            FocusSettingsView()
                .tabItem { Label("Focus", systemImage: "timer") }
            DataSettingsView()
                .tabItem { Label("Data", systemImage: "externaldrive") }
        }
        .frame(width: 460, height: 360)
    }
}

struct GeneralSettingsView: View {
    @AppStorage(SettingsKeys.dailyTaskGoal) private var dailyTaskGoal = 5
    @AppStorage(SettingsKeys.dailyFocusGoalMinutes) private var dailyFocusGoal = 120

    var body: some View {
        Form {
            Section("Daily goals") {
                Stepper("Tasks per day: \(dailyTaskGoal)", value: $dailyTaskGoal, in: 1...50)
                Stepper("Focus minutes per day: \(dailyFocusGoal)", value: $dailyFocusGoal, in: 15...600, step: 15)
            }
            Section {
                Text("Goals are shown on the Dashboard and the Focus screen to keep you honest.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct FocusSettingsView: View {
    @AppStorage(SettingsKeys.workMinutes) private var workMinutes = 25
    @AppStorage(SettingsKeys.shortBreakMinutes) private var shortBreakMinutes = 5
    @AppStorage(SettingsKeys.longBreakMinutes) private var longBreakMinutes = 15
    @AppStorage(SettingsKeys.sessionsUntilLongBreak) private var sessionsUntilLongBreak = 4
    @AppStorage(SettingsKeys.autoStartNext) private var autoStartNext = false
    @AppStorage(SettingsKeys.soundEnabled) private var soundEnabled = true
    @AppStorage(SettingsKeys.notificationsEnabled) private var notificationsEnabled = true

    var body: some View {
        Form {
            Section("Durations") {
                Stepper("Focus: \(workMinutes) min", value: $workMinutes, in: 5...120, step: 5)
                Stepper("Short break: \(shortBreakMinutes) min", value: $shortBreakMinutes, in: 1...30)
                Stepper("Long break: \(longBreakMinutes) min", value: $longBreakMinutes, in: 5...60, step: 5)
                Stepper("Sessions until long break: \(sessionsUntilLongBreak)", value: $sessionsUntilLongBreak, in: 2...8)
            }
            Section("Behavior") {
                Toggle("Auto-start next phase", isOn: $autoStartNext)
                Toggle("Play sound when a phase ends", isOn: $soundEnabled)
                Toggle("Send notification when a phase ends", isOn: $notificationsEnabled)
            }
            Section {
                Text("Duration changes apply from the next phase; the current countdown keeps its length.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DataSettingsView: View {
    @Environment(AppStore.self) private var store

    @State private var exporting = false
    @State private var exportDocument: BackupDocument?
    @State private var importing = false
    @State private var pendingImportData: Data?
    @State private var confirmingImport = false
    @State private var confirmingErase = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section("Local storage") {
                Text("All data is stored on this Mac in a single JSON file. The app has no network access, so nothing ever leaves your machine. A timestamped backup is taken automatically once per launch (last 20 kept).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Show Data Folder in Finder") {
                    try? Persistence.ensureDirectories()
                    NSWorkspace.shared.activateFileViewerSelecting([Persistence.dataFileURL])
                }
            }

            Section("Backup") {
                Button("Export Backup…") {
                    if let data = store.exportData() {
                        exportDocument = BackupDocument(data: data)
                        exporting = true
                    }
                }
                Button("Import Backup…") {
                    importing = true
                }
            }

            Section("Danger zone") {
                Button("Erase All Data…", role: .destructive) {
                    confirmingErase = true
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "Productive-backup"
        ) { result in
            switch result {
            case .success:
                statusMessage = "Backup exported."
            case .failure(let error):
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                readImportFile(at: url)
            case .failure(let error):
                statusMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .alert("Replace all data?", isPresented: $confirmingImport) {
            Button("Replace", role: .destructive) {
                performImport()
            }
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
            }
        } message: {
            Text("Importing replaces every task, project, habit, note, and focus session with the backup's contents. The current data is backed up first.")
        }
        .alert("Erase all data?", isPresented: $confirmingErase) {
            Button("Erase Everything", role: .destructive) {
                store.eraseAllData()
                statusMessage = "All data erased. A backup of the previous state was kept in the Backups folder."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every task, project, habit, note, and focus session. The current data is backed up first, but the app will start empty.")
        }
    }

    private func readImportFile(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            pendingImportData = try Data(contentsOf: url)
            confirmingImport = true
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func performImport() {
        guard let data = pendingImportData else { return }
        pendingImportData = nil
        do {
            try store.importData(data)
            statusMessage = "Backup imported."
        } catch {
            statusMessage = "Import failed: the file is not a valid Productive backup."
        }
    }
}

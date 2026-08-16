import SwiftUI
import AppKit

@main
struct ProductiveApp: App {
    @State private var store: AppStore

    init() {
        UserDefaults.standard.register(defaults: SettingsKeys.defaults)
        _store = State(initialValue: AppStore())
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 880, minHeight: 540)
        }
        .defaultSize(width: 1080, height: 700)
        .commands {
            AppCommands(store: store)
        }

        MenuBarExtra {
            MenuBarView()
                .environment(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}

struct MenuBarLabel: View {
    var store: AppStore

    var body: some View {
        if store.focusTimer.isRunning {
            Text(store.focusTimer.menuTitle)
                .monospacedDigit()
        } else {
            Image(systemName: "checkmark.circle")
        }
    }
}

struct AppCommands: Commands {
    let store: AppStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") {
                store.requestQuickAdd()
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("Go") {
            Button("Today") { store.selection = .today }
                .keyboardShortcut("1", modifiers: .command)
            Button("Upcoming") { store.selection = .upcoming }
                .keyboardShortcut("2", modifiers: .command)
            Button("All Tasks") { store.selection = .all }
                .keyboardShortcut("3", modifiers: .command)
            Button("Flagged") { store.selection = .flagged }
                .keyboardShortcut("4", modifiers: .command)
            Button("Dashboard") { store.selection = .dashboard }
                .keyboardShortcut("5", modifiers: .command)
            Button("Focus") { store.selection = .focus }
                .keyboardShortcut("6", modifiers: .command)
            Button("Habits") { store.selection = .habits }
                .keyboardShortcut("7", modifiers: .command)
            Button("Notes") { store.selection = .notes }
                .keyboardShortcut("8", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button("Productive Help") {
                if let url = URL(string: "https://github.com/kunalkumarofficial/productive#readme") {
                    NSWorkspace.shared.open(url)
                }
            }
        }

        CommandMenu("Timer") {
            Button("Start / Pause") { store.focusTimer.toggle() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Skip Phase") { store.focusTimer.skip() }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            Button("Reset Timer") { store.focusTimer.reset() }
                .keyboardShortcut("0", modifiers: [.command, .shift])
        }
    }
}

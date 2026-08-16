import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    @State private var quickAddText = ""
    @State private var justAdded = false

    private var timer: FocusTimer { store.focusTimer }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Productive")
                    .font(.headline)
                Spacer()
                Text("\(store.completedTodayCount) done · \(store.todayCount) left today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: justAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .foregroundStyle(justAdded ? Color.green : Color.accentColor)
                TextField("Quick add task…", text: $quickAddText)
                    .textFieldStyle(.plain)
                    .onSubmit(submitQuickAdd)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(0.07))
            )

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.phase.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(timer.timeString)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer()
                Button {
                    timer.toggle()
                } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                }
                .help(timer.isRunning ? "Pause" : "Start")
                Button {
                    timer.skip()
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .help("Skip phase")
            }

            Divider()

            HStack {
                Button("Open Productive") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 300)
    }

    private func submitQuickAdd() {
        if store.quickAddTask(quickAddText, defaultDueDate: Date().startOfDay) != nil {
            quickAddText = ""
            justAdded = true
            Task {
                try? await Task.sleep(for: .seconds(1))
                justAdded = false
            }
        }
    }
}

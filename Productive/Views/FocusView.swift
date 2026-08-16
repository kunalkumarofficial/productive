import SwiftUI

struct FocusView: View {
    @Environment(AppStore.self) private var store
    @AppStorage(SettingsKeys.dailyFocusGoalMinutes) private var focusGoal = 120

    private var timer: FocusTimer { store.focusTimer }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(timer.phase.rawValue)
                .font(.title2.weight(.semibold))
                .foregroundStyle(timer.phase == .work ? Color.primary : Color.teal)

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(
                        timer.phase == .work ? Color.accentColor : Color.teal,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.4), value: timer.progress)

                VStack(spacing: 6) {
                    Text(timer.timeString)
                        .font(.system(size: 52, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    cycleDots
                }
            }
            .frame(width: 240, height: 240)

            HStack(spacing: 12) {
                Button {
                    timer.toggle()
                } label: {
                    Label(
                        timer.isRunning ? "Pause" : "Start",
                        systemImage: timer.isRunning ? "pause.fill" : "play.fill"
                    )
                    .frame(width: 90)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    timer.skip()
                } label: {
                    Label("Skip", systemImage: "forward.end.fill")
                }
                .controlSize(.large)
                .help("Skip to the next phase without crediting this one")

                Button {
                    timer.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .controlSize(.large)
            }

            VStack(spacing: 8) {
                let minutes = store.focusMinutesToday
                Text("\(minutes) min focused today · goal \(focusGoal) min")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(min(minutes, focusGoal)), total: Double(max(focusGoal, 1)))
                    .frame(width: 260)
            }

            Spacer()

            Text("Durations can be changed in Settings (⌘,)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Focus")
    }

    private var cycleDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(timer.sessionsUntilLongBreak, 1), id: \.self) { index in
                Circle()
                    .fill(index < timer.completedInCycle ? Color.accentColor : Color.primary.opacity(0.15))
                    .frame(width: 8, height: 8)
            }
        }
        .help("Focus sessions completed before the next long break")
    }
}

import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @AppStorage(SettingsKeys.dailyTaskGoal) private var dailyTaskGoal = 5
    @AppStorage(SettingsKeys.dailyFocusGoalMinutes) private var dailyFocusGoal = 120

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statTiles

                GroupBox("Tasks completed — last 14 days") {
                    Chart(store.dailyCompletedStats(days: 14)) { stat in
                        BarMark(
                            x: .value("Day", stat.date, unit: .day),
                            y: .value("Tasks", stat.value)
                        )
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(3)
                    }
                    .frame(height: 160)
                    .padding(.top, 6)
                }

                GroupBox("Focus minutes — last 14 days") {
                    Chart(store.dailyFocusStats(days: 14)) { stat in
                        BarMark(
                            x: .value("Day", stat.date, unit: .day),
                            y: .value("Minutes", stat.value)
                        )
                        .foregroundStyle(Color.teal)
                        .cornerRadius(3)
                    }
                    .frame(height: 160)
                    .padding(.top, 6)
                }

                if !store.habits.isEmpty {
                    GroupBox("Habit streaks") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.habits) { habit in
                                HStack {
                                    Text("\(habit.emoji)  \(habit.name)")
                                    Spacer()
                                    let streak = store.streak(for: habit)
                                    Text(streak > 0 ? "🔥 \(streak)" : "—")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        .padding(.top, 6)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Dashboard")
    }

    private var statTiles: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            StatTile(
                title: "Done today",
                value: "\(store.completedTodayCount)/\(dailyTaskGoal)",
                systemImage: "checkmark.circle.fill",
                tint: .green
            )
            StatTile(
                title: "Done this week",
                value: "\(store.completedThisWeekCount)",
                systemImage: "calendar.badge.checkmark",
                tint: .blue
            )
            StatTile(
                title: "Focus today",
                value: "\(store.focusMinutesToday)m/\(dailyFocusGoal)m",
                systemImage: "timer",
                tint: .teal
            )
            StatTile(
                title: "Best streak",
                value: store.bestStreak > 0 ? "\(store.bestStreak)d" : "—",
                systemImage: "flame.fill",
                tint: .orange
            )
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

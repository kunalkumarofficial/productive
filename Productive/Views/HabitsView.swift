import SwiftUI

struct HabitsView: View {
    @Environment(AppStore.self) private var store
    @State private var newHabitName = ""
    @State private var newHabitEmoji = ""

    private var lastSevenDays: [Date] {
        (0..<7).reversed().map { DateHelper.daysAgo($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            addBar

            if store.habits.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No habits yet",
                    systemImage: "repeat",
                    description: Text("Add a small daily habit above and build a streak.")
                )
                Spacer()
            } else {
                List {
                    ForEach(store.habits) { habit in
                        HabitRowView(habit: habit, days: lastSevenDays)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Habits")
    }

    private var addBar: some View {
        HStack(spacing: 8) {
            TextField("🎯", text: $newHabitEmoji)
                .textFieldStyle(.roundedBorder)
                .frame(width: 44)
                .help("Optional emoji")
            TextField("New habit, e.g. “Review inbox to zero”", text: $newHabitName)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addHabit)
            Button("Add", action: addHabit)
                .disabled(newHabitName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
    }

    private func addHabit() {
        let name = newHabitName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.addHabit(name: name, emoji: newHabitEmoji)
        newHabitName = ""
        newHabitEmoji = ""
    }
}

struct HabitRowView: View {
    let habit: Habit
    let days: [Date]

    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 16) {
            Text(habit.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                let streak = store.streak(for: habit)
                Text(streak > 0 ? "🔥 \(streak) day streak" : "No streak yet — start today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                ForEach(days, id: \.self) { day in
                    let done = store.habitDone(habit, on: day)
                    VStack(spacing: 4) {
                        Text(DateHelper.weekdayLetterFormatter.string(from: day))
                            .font(.caption2)
                            .foregroundStyle(day.isToday ? Color.accentColor : Color.secondary)
                        Button {
                            store.toggleHabit(habit.id, on: day)
                        } label: {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(done ? Color.green : Color.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .help(DateHelper.shortFormatter.string(from: day))
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button("Delete Habit", role: .destructive) {
                store.deleteHabit(habit.id)
            }
        }
    }
}

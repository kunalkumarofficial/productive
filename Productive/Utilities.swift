import Foundation
import SwiftUI

// MARK: - Day keys

enum DayKey {
    static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    static func key(for date: Date) -> String {
        formatter.string(from: date)
    }
}

// MARK: - Date helpers

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
}

enum DateHelper {
    static var endOfToday: Date {
        let start = Date().startOfDay
        return Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
    }

    static func daysAgo(_ days: Int) -> Date {
        let start = Date().startOfDay
        return Calendar.current.date(byAdding: .day, value: -days, to: start) ?? start
    }

    static func daysAhead(_ days: Int) -> Date {
        let start = Date().startOfDay
        return Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
    }

    static let sectionFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df
    }()

    static let shortFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    static let weekdayLetterFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEEE"
        return df
    }()

    static let chartDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "M/d"
        return df
    }()

    static func sectionTitle(for date: Date) -> String {
        if date.isToday { return "Today" }
        if date.isTomorrow { return "Tomorrow" }
        return sectionFormatter.string(from: date)
    }

    /// Human description of a due date, plus whether it is overdue.
    static func dueDescription(for date: Date, relativeTo now: Date = Date()) -> (text: String, isOverdue: Bool) {
        let overdue = date.startOfDay < now.startOfDay
        if Calendar.current.isDateInYesterday(date) { return ("Yesterday", true) }
        if date.isToday { return ("Today", false) }
        if date.isTomorrow { return ("Tomorrow", false) }
        return (shortFormatter.string(from: date), overdue)
    }

    /// Resolves quick-add tokens like "@today", "@tomorrow", "@friday", "@week".
    static func parseDueToken(_ token: String) -> Date? {
        let calendar = Calendar.current
        let today = Date().startOfDay
        switch token {
        case "today", "tod": return today
        case "tomorrow", "tom", "tmr": return calendar.date(byAdding: .day, value: 1, to: today)
        case "week", "nextweek": return calendar.date(byAdding: .day, value: 7, to: today)
        default: break
        }
        let weekdays = [
            "sunday": 1, "sun": 1,
            "monday": 2, "mon": 2,
            "tuesday": 3, "tue": 3, "tues": 3,
            "wednesday": 4, "wed": 4,
            "thursday": 5, "thu": 5, "thur": 5, "thurs": 5,
            "friday": 6, "fri": 6,
            "saturday": 7, "sat": 7,
        ]
        if let weekday = weekdays[token] {
            var components = DateComponents()
            components.weekday = weekday
            return calendar.nextDate(after: today, matching: components, matchingPolicy: .nextTime)
        }
        return nil
    }
}

// MARK: - Project colors

enum ProjectPalette {
    static let names = [
        "red", "orange", "yellow", "green", "teal",
        "blue", "indigo", "purple", "pink", "brown", "gray",
    ]

    static func color(named name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray": return .gray
        default: return .blue
        }
    }
}

// MARK: - Settings

enum SettingsKeys {
    static let workMinutes = "focus.workMinutes"
    static let shortBreakMinutes = "focus.shortBreakMinutes"
    static let longBreakMinutes = "focus.longBreakMinutes"
    static let sessionsUntilLongBreak = "focus.sessionsUntilLongBreak"
    static let autoStartNext = "focus.autoStartNext"
    static let soundEnabled = "focus.soundEnabled"
    static let notificationsEnabled = "focus.notificationsEnabled"
    static let dailyTaskGoal = "goals.dailyTasks"
    static let dailyFocusGoalMinutes = "goals.dailyFocusMinutes"

    static var defaults: [String: Any] {
        [
            workMinutes: 25,
            shortBreakMinutes: 5,
            longBreakMinutes: 15,
            sessionsUntilLongBreak: 4,
            autoStartNext: false,
            soundEnabled: true,
            notificationsEnabled: true,
            dailyTaskGoal: 5,
            dailyFocusGoalMinutes: 120,
        ]
    }
}

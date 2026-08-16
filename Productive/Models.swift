import Foundation

// MARK: - Priority

enum TaskPriority: Int, Codable, CaseIterable, Identifiable, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Parses quick-add tokens like "!high", "!h", "!3".
    static func parse(_ token: String) -> TaskPriority? {
        switch token.lowercased() {
        case "high", "hi", "h", "3": return .high
        case "medium", "med", "m", "2": return .medium
        case "low", "l", "1": return .low
        default: return nil
        }
    }
}

// MARK: - Task

struct TodoTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var notes: String = ""
    var priority: TaskPriority = .medium
    var dueDate: Date?
    var projectID: UUID?
    var isFlagged: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date?
    var createdAt = Date()
}

// MARK: - Project

struct Project: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorName: String = "blue"
    var createdAt = Date()
}

// MARK: - Habit

struct Habit: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var emoji: String = "🎯"
    /// Day keys ("2026-08-16") on which the habit was completed.
    var completedDays: Set<String> = []
    var createdAt = Date()
}

// MARK: - Note

struct Note: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String = "Untitled"
    var body: String = ""
    var createdAt = Date()
    var updatedAt = Date()
}

// MARK: - Focus session

struct FocusSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var completedAt = Date()
    var minutes: Int
}

// MARK: - Persisted container

struct AppData: Codable {
    var schemaVersion: Int = 1
    var tasks: [TodoTask] = []
    var projects: [Project] = []
    var habits: [Habit] = []
    var notes: [Note] = []
    var focusSessions: [FocusSession] = []

    init() {}

    // Tolerant decoding: a missing collection never sinks the whole file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        tasks = try container.decodeIfPresent([TodoTask].self, forKey: .tasks) ?? []
        projects = try container.decodeIfPresent([Project].self, forKey: .projects) ?? []
        habits = try container.decodeIfPresent([Habit].self, forKey: .habits) ?? []
        notes = try container.decodeIfPresent([Note].self, forKey: .notes) ?? []
        focusSessions = try container.decodeIfPresent([FocusSession].self, forKey: .focusSessions) ?? []
    }
}

// MARK: - Navigation

enum SidebarItem: Hashable {
    case today
    case upcoming
    case all
    case flagged
    case logbook
    case dashboard
    case focus
    case habits
    case notes
    case project(UUID)
}

enum TaskScope: Hashable {
    case today
    case upcoming
    case all
    case flagged
    case project(UUID)
}

struct TaskSection: Identifiable {
    var id: String
    var title: String
    var tasks: [TodoTask]
}

struct DayStat: Identifiable {
    var date: Date
    var value: Int
    var id: Date { date }
}

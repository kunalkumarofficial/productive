import Foundation
import Observation
import AppKit

/// Single source of truth for all app data. Everything is kept in memory and
/// persisted to a local JSON file with debounced, atomic saves.
@MainActor
@Observable
final class AppStore {
    private(set) var tasks: [TodoTask] = []
    private(set) var projects: [Project] = []
    private(set) var habits: [Habit] = []
    private(set) var notes: [Note] = []
    private(set) var focusSessions: [FocusSession] = []

    var selection: SidebarItem? = .today
    var searchText = ""

    /// Incremented to ask the visible task list to focus its quick-add field.
    private(set) var quickAddRequestCount = 0

    var loadErrorMessage: String?
    var saveErrorMessage: String?

    let focusTimer = FocusTimer()

    private var pendingSave: Task<Void, Never>?
    private var terminationObserver: NSObjectProtocol?

    init(loadFromDisk: Bool = true) {
        focusTimer.onWorkSessionCompleted = { [weak self] minutes in
            self?.logFocusSession(minutes: minutes)
        }
        if loadFromDisk {
            loadData()
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.saveNow()
            }
        }
    }

    // MARK: - Persistence

    private func loadData() {
        do {
            if let data = try Persistence.load() {
                apply(data)
                Persistence.backUpCurrentFile()
            } else {
                seedSampleData()
                saveNow()
            }
        } catch {
            loadErrorMessage = """
            Your data file could not be read, so Productive started fresh. \
            The unreadable file was preserved in the data folder \
            (Settings → Data → Show Data Folder).
            """
            seedSampleData()
            saveNow()
        }
    }

    private func apply(_ data: AppData) {
        tasks = data.tasks
        projects = data.projects
        habits = data.habits
        notes = data.notes
        focusSessions = data.focusSessions
    }

    var snapshot: AppData {
        var data = AppData()
        data.tasks = tasks
        data.projects = projects
        data.habits = habits
        data.notes = notes
        data.focusSessions = focusSessions
        return data
    }

    func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        do {
            try Persistence.save(snapshot)
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = "Saving failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Export / import

    func exportData() -> Data? {
        try? Persistence.makeEncoder().encode(snapshot)
    }

    func importData(_ data: Data) throws {
        // Reject files that parse as JSON but are clearly not a Productive
        // backup — otherwise a stray .json would silently replace everything
        // with empty data (the tolerant decoder treats missing keys as []).
        let knownKeys: Set<String> = [
            "schemaVersion", "tasks", "projects", "habits", "notes", "focusSessions",
        ]
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any],
              dict.keys.contains(where: knownKeys.contains) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoded = try Persistence.makeDecoder().decode(AppData.self, from: data)
        Persistence.backUpCurrentFile()
        apply(decoded)
        saveNow()
    }

    func eraseAllData() {
        Persistence.backUpCurrentFile()
        tasks = []
        projects = []
        habits = []
        notes = []
        focusSessions = []
        saveNow()
    }

    // MARK: - Quick add

    func requestQuickAdd() {
        switch selection {
        case .today, .upcoming, .all, .flagged, .project:
            break
        default:
            selection = .today
        }
        quickAddRequestCount += 1
    }

    /// Parses lightweight syntax: "!high" priority, "#Project" project,
    /// "@today" / "@tomorrow" / "@friday" due dates.
    @discardableResult
    func quickAddTask(
        _ input: String,
        defaultProjectID: UUID? = nil,
        defaultDueDate: Date? = nil
    ) -> TodoTask? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var titleWords: [String] = []
        var priority = TaskPriority.medium
        var dueDate = defaultDueDate
        var projectID = defaultProjectID

        for word in trimmed.split(separator: " ") {
            let token = String(word)
            if token.hasPrefix("!"), let parsed = TaskPriority.parse(String(token.dropFirst())) {
                priority = parsed
            } else if token.hasPrefix("#"), token.count > 1,
                      let project = matchProject(String(token.dropFirst())) {
                projectID = project.id
            } else if token.hasPrefix("@"), token.count > 1,
                      let parsed = DateHelper.parseDueToken(String(token.dropFirst()).lowercased()) {
                dueDate = parsed
            } else {
                titleWords.append(token)
            }
        }

        let title = titleWords.joined(separator: " ")
        guard !title.isEmpty else { return nil }

        var task = TodoTask(title: title)
        task.priority = priority
        task.dueDate = dueDate
        task.projectID = projectID
        tasks.append(task)
        scheduleSave()
        return task
    }

    private func matchProject(_ query: String) -> Project? {
        let lowered = query.lowercased()
        return projects.first { $0.name.lowercased().hasPrefix(lowered) }
    }

    // MARK: - Tasks

    func task(with id: UUID) -> TodoTask? {
        tasks.first { $0.id == id }
    }

    func upsertTask(_ task: TodoTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        scheduleSave()
    }

    func deleteTask(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        scheduleSave()
    }

    func toggleCompletion(of id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isCompleted.toggle()
        tasks[index].completedAt = tasks[index].isCompleted ? Date() : nil
        scheduleSave()
    }

    func setFlag(_ flagged: Bool, for id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isFlagged = flagged
        scheduleSave()
    }

    func setPriority(_ priority: TaskPriority, for id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].priority = priority
        scheduleSave()
    }

    func setProject(_ projectID: UUID?, for id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].projectID = projectID
        scheduleSave()
    }

    func clearLogbook() {
        tasks.removeAll { $0.isCompleted }
        scheduleSave()
    }

    // MARK: - Task queries

    private func matchesSearch(_ task: TodoTask) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return task.title.localizedCaseInsensitiveContains(query)
            || task.notes.localizedCaseInsensitiveContains(query)
    }

    private func sortedForDisplay(_ list: [TodoTask]) -> [TodoTask] {
        list.sorted { a, b in
            if a.priority != b.priority { return a.priority > b.priority }
            switch (a.dueDate, b.dueDate) {
            case let (da?, db?) where da != db: return da < db
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.createdAt < b.createdAt
            }
        }
    }

    var incompleteTasks: [TodoTask] {
        tasks.filter { !$0.isCompleted }
    }

    func sections(for scope: TaskScope) -> [TaskSection] {
        let matching = incompleteTasks.filter(matchesSearch)
        switch scope {
        case .today:
            let due = matching.filter { task in
                guard let date = task.dueDate else { return false }
                return date < DateHelper.endOfToday
            }
            let overdue = due.filter { ($0.dueDate ?? Date()).startOfDay < Date().startOfDay }
            let today = due.filter { !(($0.dueDate ?? Date()).startOfDay < Date().startOfDay) }
            var result: [TaskSection] = []
            if !overdue.isEmpty {
                result.append(TaskSection(id: "overdue", title: "Overdue", tasks: sortedForDisplay(overdue)))
            }
            if !today.isEmpty {
                result.append(TaskSection(id: "today", title: "Today", tasks: sortedForDisplay(today)))
            }
            return result

        case .upcoming:
            let future = matching.filter { task in
                guard let date = task.dueDate else { return false }
                return date >= DateHelper.endOfToday
            }
            let grouped = Dictionary(grouping: future) { ($0.dueDate ?? Date()).startOfDay }
            return grouped.keys.sorted().map { day in
                TaskSection(
                    id: "day-\(DayKey.key(for: day))",
                    title: DateHelper.sectionTitle(for: day),
                    tasks: sortedForDisplay(grouped[day] ?? [])
                )
            }

        case .all:
            var result: [TaskSection] = []
            let inbox = matching.filter { $0.projectID == nil }
            if !inbox.isEmpty {
                result.append(TaskSection(id: "inbox", title: "Inbox", tasks: sortedForDisplay(inbox)))
            }
            for project in projects {
                let inProject = matching.filter { $0.projectID == project.id }
                if !inProject.isEmpty {
                    result.append(TaskSection(
                        id: "project-\(project.id.uuidString)",
                        title: project.name,
                        tasks: sortedForDisplay(inProject)
                    ))
                }
            }
            return result

        case .flagged:
            let flagged = matching.filter { $0.isFlagged }
            guard !flagged.isEmpty else { return [] }
            return [TaskSection(id: "flagged", title: "", tasks: sortedForDisplay(flagged))]

        case .project(let id):
            let inProject = matching.filter { $0.projectID == id }
            guard !inProject.isEmpty else { return [] }
            return [TaskSection(id: "project", title: "", tasks: sortedForDisplay(inProject))]
        }
    }

    /// Completed tasks relevant to a scope, newest first.
    func completedTasks(for scope: TaskScope) -> [TodoTask] {
        let completed = tasks.filter { $0.isCompleted && matchesSearch($0) }
        let filtered: [TodoTask]
        switch scope {
        case .today:
            filtered = completed.filter { ($0.completedAt ?? .distantPast).isToday }
        case .upcoming:
            filtered = []
        case .all:
            filtered = completed
        case .flagged:
            filtered = completed.filter { $0.isFlagged }
        case .project(let id):
            filtered = completed.filter { $0.projectID == id }
        }
        return filtered.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var logbookSections: [TaskSection] {
        let completed = tasks.filter { $0.isCompleted && matchesSearch($0) }
        let grouped = Dictionary(grouping: completed) { ($0.completedAt ?? .distantPast).startOfDay }
        return grouped.keys.sorted(by: >).map { day in
            TaskSection(
                id: "log-\(DayKey.key(for: day))",
                title: DateHelper.sectionTitle(for: day),
                tasks: (grouped[day] ?? []).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            )
        }
    }

    // MARK: - Badge counts

    var todayCount: Int {
        incompleteTasks.filter { task in
            guard let date = task.dueDate else { return false }
            return date < DateHelper.endOfToday
        }.count
    }

    var flaggedCount: Int {
        incompleteTasks.filter { $0.isFlagged }.count
    }

    var allCount: Int {
        incompleteTasks.count
    }

    func incompleteCount(inProject id: UUID) -> Int {
        incompleteTasks.filter { $0.projectID == id }.count
    }

    // MARK: - Projects

    func project(with id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    @discardableResult
    func addProject(name: String, colorName: String) -> Project {
        let project = Project(name: name, colorName: colorName)
        projects.append(project)
        scheduleSave()
        return project
    }

    func updateProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
        scheduleSave()
    }

    /// Deletes the project; its tasks move to the inbox.
    func deleteProject(_ id: UUID) {
        projects.removeAll { $0.id == id }
        for index in tasks.indices where tasks[index].projectID == id {
            tasks[index].projectID = nil
        }
        if case .project(let selected) = selection, selected == id {
            selection = .today
        }
        scheduleSave()
    }

    // MARK: - Habits

    @discardableResult
    func addHabit(name: String, emoji: String) -> Habit {
        var habit = Habit(name: name)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespaces)
        if !trimmedEmoji.isEmpty {
            habit.emoji = trimmedEmoji
        }
        habits.append(habit)
        scheduleSave()
        return habit
    }

    func deleteHabit(_ id: UUID) {
        habits.removeAll { $0.id == id }
        scheduleSave()
    }

    func toggleHabit(_ id: UUID, on date: Date) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        let key = DayKey.key(for: date)
        if habits[index].completedDays.contains(key) {
            habits[index].completedDays.remove(key)
        } else {
            habits[index].completedDays.insert(key)
        }
        scheduleSave()
    }

    func habitDone(_ habit: Habit, on date: Date) -> Bool {
        habit.completedDays.contains(DayKey.key(for: date))
    }

    /// Consecutive completed days ending today (or yesterday if today is pending).
    func streak(for habit: Habit) -> Int {
        let calendar = Calendar.current
        var day = Date().startOfDay
        if !habit.completedDays.contains(DayKey.key(for: day)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while habit.completedDays.contains(DayKey.key(for: day)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    var bestStreak: Int {
        habits.map { streak(for: $0) }.max() ?? 0
    }

    // MARK: - Notes

    func note(with id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    @discardableResult
    func addNote() -> Note {
        let note = Note()
        notes.insert(note, at: 0)
        scheduleSave()
        return note
    }

    func updateNote(_ note: Note) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = note
        updated.updatedAt = Date()
        notes[index] = updated
        scheduleSave()
    }

    func deleteNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
        scheduleSave()
    }

    var sortedNotes: [Note] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty
            ? notes
            : notes.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.body.localizedCaseInsensitiveContains(query)
            }
        return filtered.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Focus sessions

    func logFocusSession(minutes: Int) {
        focusSessions.append(FocusSession(minutes: minutes))
        scheduleSave()
    }

    func focusMinutes(on date: Date) -> Int {
        focusSessions
            .filter { Calendar.current.isDate($0.completedAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.minutes }
    }

    var focusMinutesToday: Int {
        focusMinutes(on: Date())
    }

    // MARK: - Statistics

    func completedCount(on date: Date) -> Int {
        tasks.filter { task in
            guard task.isCompleted, let done = task.completedAt else { return false }
            return Calendar.current.isDate(done, inSameDayAs: date)
        }.count
    }

    var completedTodayCount: Int {
        completedCount(on: Date())
    }

    var completedThisWeekCount: Int {
        let weekAgo = DateHelper.daysAgo(6)
        return tasks.filter { task in
            guard task.isCompleted, let done = task.completedAt else { return false }
            return done >= weekAgo
        }.count
    }

    func dailyCompletedStats(days: Int) -> [DayStat] {
        (0..<days).reversed().map { offset in
            let day = DateHelper.daysAgo(offset)
            return DayStat(date: day, value: completedCount(on: day))
        }
    }

    func dailyFocusStats(days: Int) -> [DayStat] {
        (0..<days).reversed().map { offset in
            let day = DateHelper.daysAgo(offset)
            return DayStat(date: day, value: focusMinutes(on: day))
        }
    }

    // MARK: - Sample data

    private func seedSampleData() {
        let personal = Project(name: "Personal", colorName: "teal")
        let work = Project(name: "Work", colorName: "indigo")
        projects = [personal, work]

        var welcome = TodoTask(title: "Welcome to Productive — click the circle to complete me")
        welcome.dueDate = Date().startOfDay
        welcome.priority = .high

        var quickAdd = TodoTask(title: "Try quick add: type a task like \"Plan sprint @tomorrow !high #Work\"")
        quickAdd.dueDate = Date().startOfDay
        quickAdd.projectID = personal.id

        var focus = TodoTask(title: "Run a focus session from the Focus tab (⌘6)")
        focus.dueDate = DateHelper.daysAhead(1)
        focus.projectID = personal.id

        var review = TodoTask(title: "Review the Dashboard at the end of the week")
        review.dueDate = DateHelper.daysAhead(4)
        review.projectID = work.id
        review.isFlagged = true

        tasks = [welcome, quickAdd, focus, review]

        habits = [Habit(name: "Plan tomorrow before signing off", emoji: "📝")]

        var note = Note()
        note.title = "Read me"
        note.body = """
        Everything in Productive is stored locally on this Mac — there is no \
        account, no sync, and the app has no network access at all.

        Data file: ~/Library (Application Support/Productive inside the app's \
        sandbox container). Use Settings → Data to export a backup, import one, \
        or reveal the folder in Finder. A timestamped backup is also taken \
        automatically once per launch.

        Handy shortcuts:
        • ⌘N — new task
        • ⌘1…⌘8 — switch sections
        • ⇧⌘P — start/pause the focus timer
        """
        notes = [note]
    }
}

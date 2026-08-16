import SwiftUI

struct TaskListView: View {
    let scope: TaskScope
    let title: String

    @Environment(AppStore.self) private var store
    @State private var quickAddText = ""
    @FocusState private var quickAddFocused: Bool
    @State private var editingTask: TodoTask?
    @State private var showCompleted = false

    var body: some View {
        let sections = store.sections(for: scope)
        let completed = store.completedTasks(for: scope)

        VStack(spacing: 0) {
            quickAddBar

            if sections.isEmpty && completed.isEmpty {
                Spacer()
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "checkmark.seal",
                    description: Text(emptyDescription)
                )
                Spacer()
            } else {
                List {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.tasks) { task in
                                TaskRowView(task: task) {
                                    editingTask = task
                                }
                            }
                        } header: {
                            if !section.title.isEmpty {
                                Text(section.title)
                            }
                        }
                    }

                    if !completed.isEmpty {
                        Section {
                            DisclosureGroup(isExpanded: $showCompleted) {
                                ForEach(completed) { task in
                                    TaskRowView(task: task) {
                                        editingTask = task
                                    }
                                }
                            } label: {
                                Text("Completed (\(completed.count))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(title)
        .sheet(item: $editingTask) { task in
            TaskEditView(task: task)
        }
        .onChange(of: store.quickAddRequestCount) {
            quickAddFocused = true
        }
    }

    private var quickAddBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
            TextField(
                "Add a task — try “Ship report @tomorrow !high #Work”",
                text: $quickAddText
            )
            .textFieldStyle(.plain)
            .focused($quickAddFocused)
            .onSubmit(submitQuickAdd)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
        )
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func submitQuickAdd() {
        var defaultProjectID: UUID?
        if case .project(let id) = scope {
            defaultProjectID = id
        }
        let defaultDue: Date? = scope == .today ? Date().startOfDay : nil
        if store.quickAddTask(
            quickAddText,
            defaultProjectID: defaultProjectID,
            defaultDueDate: defaultDue
        ) != nil {
            quickAddText = ""
        }
    }

    private var emptyTitle: String {
        switch scope {
        case .today: return "All clear for today"
        case .upcoming: return "Nothing scheduled"
        case .all: return "No tasks yet"
        case .flagged: return "No flagged tasks"
        case .project: return "No tasks in this project"
        }
    }

    private var emptyDescription: String {
        if !store.searchText.isEmpty {
            return "No tasks match your search."
        }
        return "Add a task above, or press ⌘N from anywhere."
    }
}

struct TaskRowView: View {
    let task: TodoTask
    var onEdit: () -> Void

    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button {
                store.toggleCompletion(of: task.id)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.green : checkboxTint)
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "Mark incomplete" : "Mark complete")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let dueDate = task.dueDate {
                        let due = DateHelper.dueDescription(for: dueDate)
                        Label(due.text, systemImage: "calendar")
                            .foregroundStyle(due.isOverdue && !task.isCompleted ? Color.red : Color.secondary)
                    }
                    if let projectID = task.projectID,
                       let project = store.project(with: projectID) {
                        Label {
                            Text(project.name)
                        } icon: {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(ProjectPalette.color(named: project.colorName))
                                .imageScale(.small)
                        }
                        .foregroundStyle(.secondary)
                    }
                    if !task.notes.isEmpty {
                        Image(systemName: "text.alignleft")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            if task.isFlagged {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        .contextMenu {
            Button(task.isCompleted ? "Mark Incomplete" : "Complete") {
                store.toggleCompletion(of: task.id)
            }
            Button("Edit…", action: onEdit)
            Button(task.isFlagged ? "Unflag" : "Flag") {
                store.setFlag(!task.isFlagged, for: task.id)
            }
            Menu("Priority") {
                ForEach(TaskPriority.allCases) { priority in
                    Button {
                        store.setPriority(priority, for: task.id)
                    } label: {
                        if task.priority == priority {
                            Label(priority.label, systemImage: "checkmark")
                        } else {
                            Text(priority.label)
                        }
                    }
                }
            }
            Menu("Move to Project") {
                Button {
                    store.setProject(nil, for: task.id)
                } label: {
                    if task.projectID == nil {
                        Label("Inbox", systemImage: "checkmark")
                    } else {
                        Text("Inbox")
                    }
                }
                ForEach(store.projects) { project in
                    Button {
                        store.setProject(project.id, for: task.id)
                    } label: {
                        if task.projectID == project.id {
                            Label(project.name, systemImage: "checkmark")
                        } else {
                            Text(project.name)
                        }
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                store.deleteTask(task.id)
            }
        }
    }

    private var checkboxTint: Color {
        switch task.priority {
        case .high: return .red
        case .medium: return .secondary
        case .low: return .secondary.opacity(0.6)
        }
    }
}

struct TaskEditView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: TodoTask
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(task: TodoTask) {
        _draft = State(initialValue: task)
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Calendar.current.startOfDay(for: Date()))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Title", text: $draft.title)

                Picker("Priority", selection: $draft.priority) {
                    ForEach(TaskPriority.allCases) { priority in
                        Text(priority.label).tag(priority)
                    }
                }

                Picker("Project", selection: $draft.projectID) {
                    Text("Inbox").tag(Optional<UUID>.none)
                    ForEach(store.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }

                Toggle("Flagged", isOn: $draft.isFlagged)

                Toggle("Due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }

                Section("Notes") {
                    TextEditor(text: $draft.notes)
                        .font(.body)
                        .frame(minHeight: 80)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Delete", role: .destructive) {
                    store.deleteTask(draft.id)
                    dismiss()
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(14)
        }
        .frame(width: 440, height: 470)
    }

    private func save() {
        var task = draft
        task.title = task.title.trimmingCharacters(in: .whitespaces)
        task.dueDate = hasDueDate ? dueDate : nil
        store.upsertTask(task)
        dismiss()
    }
}

struct LogbookView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmingClear = false

    var body: some View {
        let sections = store.logbookSections
        Group {
            if sections.isEmpty {
                ContentUnavailableView(
                    "Logbook is empty",
                    systemImage: "checkmark.circle",
                    description: Text("Completed tasks appear here, grouped by day.")
                )
            } else {
                List {
                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.tasks) { task in
                                TaskRowView(task: task) {}
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Logbook")
        .toolbar {
            Button("Clear Logbook") {
                confirmingClear = true
            }
            .disabled(sections.isEmpty)
        }
        .alert("Delete all completed tasks?", isPresented: $confirmingClear) {
            Button("Delete All", role: .destructive) {
                store.clearLogbook()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every completed task. Incomplete tasks are not affected.")
        }
    }
}

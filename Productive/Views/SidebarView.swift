import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @State private var editingProject: Project?
    @State private var showingNewProject = false
    @State private var projectPendingDeletion: Project?

    var body: some View {
        @Bindable var store = store
        List(selection: $store.selection) {
            Section("Tasks") {
                Label("Today", systemImage: "star")
                    .badge(store.todayCount)
                    .tag(SidebarItem.today)
                Label("Upcoming", systemImage: "calendar")
                    .tag(SidebarItem.upcoming)
                Label("All Tasks", systemImage: "tray.full")
                    .badge(store.allCount)
                    .tag(SidebarItem.all)
                Label("Flagged", systemImage: "flag")
                    .badge(store.flaggedCount)
                    .tag(SidebarItem.flagged)
                Label("Logbook", systemImage: "checkmark.circle")
                    .tag(SidebarItem.logbook)
            }

            Section("Productivity") {
                Label("Dashboard", systemImage: "chart.bar.xaxis")
                    .tag(SidebarItem.dashboard)
                Label("Focus", systemImage: "timer")
                    .tag(SidebarItem.focus)
                Label("Habits", systemImage: "repeat")
                    .tag(SidebarItem.habits)
                Label("Notes", systemImage: "note.text")
                    .tag(SidebarItem.notes)
            }

            Section {
                ForEach(store.projects) { project in
                    Label {
                        Text(project.name)
                    } icon: {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(ProjectPalette.color(named: project.colorName))
                            .imageScale(.small)
                    }
                    .badge(store.incompleteCount(inProject: project.id))
                    .tag(SidebarItem.project(project.id))
                    .contextMenu {
                        Button("Edit Project…") {
                            editingProject = project
                        }
                        Button("Delete Project…", role: .destructive) {
                            projectPendingDeletion = project
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Projects")
                    Spacer()
                    Button {
                        showingNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .help("New Project")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Productive")
        .sheet(isPresented: $showingNewProject) {
            ProjectEditView(project: nil)
        }
        .sheet(item: $editingProject) { project in
            ProjectEditView(project: project)
        }
        .alert(
            "Delete “\(projectPendingDeletion?.name ?? "")”?",
            isPresented: Binding(
                get: { projectPendingDeletion != nil },
                set: { if !$0 { projectPendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let project = projectPendingDeletion {
                    store.deleteProject(project.id)
                }
                projectPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                projectPendingDeletion = nil
            }
        } message: {
            Text("Its tasks will move to the inbox. This cannot be undone.")
        }
    }
}

struct ProjectEditView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let project: Project?
    @State private var name: String
    @State private var colorName: String

    init(project: Project?) {
        self.project = project
        _name = State(initialValue: project?.name ?? "")
        _colorName = State(initialValue: project?.colorName ?? "blue")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(project == nil ? "New Project" : "Edit Project")
                .font(.headline)

            TextField("Project name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                ForEach(ProjectPalette.names, id: \.self) { paletteName in
                    Button {
                        colorName = paletteName
                    } label: {
                        ZStack {
                            Circle()
                                .fill(ProjectPalette.color(named: paletteName))
                                .frame(width: 22, height: 22)
                            if colorName == paletteName {
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if var existing = project {
            existing.name = trimmed
            existing.colorName = colorName
            store.updateProject(existing)
        } else {
            store.addProject(name: trimmed, colorName: colorName)
        }
        dismiss()
    }
}

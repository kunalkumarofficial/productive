import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } detail: {
            detailView
        }
        .searchable(text: $store.searchText, placement: .sidebar, prompt: "Search")
        .alert(
            "Data Problem",
            isPresented: Binding(
                get: { store.loadErrorMessage != nil },
                set: { if !$0 { store.loadErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.loadErrorMessage ?? "")
        }
        .alert(
            "Save Failed",
            isPresented: Binding(
                get: { store.saveErrorMessage != nil },
                set: { if !$0 { store.saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.saveErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch store.selection ?? .today {
        case .today:
            TaskListView(scope: .today, title: "Today")
        case .upcoming:
            TaskListView(scope: .upcoming, title: "Upcoming")
        case .all:
            TaskListView(scope: .all, title: "All Tasks")
        case .flagged:
            TaskListView(scope: .flagged, title: "Flagged")
        case .logbook:
            LogbookView()
        case .dashboard:
            DashboardView()
        case .focus:
            FocusView()
        case .habits:
            HabitsView()
        case .notes:
            NotesView()
        case .project(let id):
            if let project = store.project(with: id) {
                TaskListView(scope: .project(id), title: project.name)
            } else {
                ContentUnavailableView("Project not found", systemImage: "folder.badge.questionmark")
            }
        }
    }
}

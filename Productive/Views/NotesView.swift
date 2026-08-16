import SwiftUI

struct NotesView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedNoteID: UUID?

    var body: some View {
        HSplitView {
            noteList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
            editor
                .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Notes")
        .toolbar {
            Button {
                let note = store.addNote()
                selectedNoteID = note.id
            } label: {
                Label("New Note", systemImage: "square.and.pencil")
            }
            .help("New Note")
        }
    }

    private var noteList: some View {
        List(selection: $selectedNoteID) {
            ForEach(store.sortedNotes) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .lineLimit(1)
                    Text(DateHelper.shortFormatter.string(from: note.updatedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .tag(note.id)
                .contextMenu {
                    Button("Delete Note", role: .destructive) {
                        if selectedNoteID == note.id {
                            selectedNoteID = nil
                        }
                        store.deleteNote(note.id)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private var editor: some View {
        if let id = selectedNoteID, let note = store.note(with: id) {
            VStack(alignment: .leading, spacing: 0) {
                TextField("Title", text: titleBinding(for: note))
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                    .padding([.horizontal, .top], 16)
                    .padding(.bottom, 8)
                Divider()
                TextEditor(text: bodyBinding(for: note))
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
        } else {
            ContentUnavailableView(
                "No note selected",
                systemImage: "note.text",
                description: Text("Select a note on the left, or create one with the toolbar button.")
            )
        }
    }

    private func titleBinding(for note: Note) -> Binding<String> {
        Binding {
            store.note(with: note.id)?.title ?? ""
        } set: { newValue in
            guard var current = store.note(with: note.id) else { return }
            current.title = newValue
            store.updateNote(current)
        }
    }

    private func bodyBinding(for note: Note) -> Binding<String> {
        Binding {
            store.note(with: note.id)?.body ?? ""
        } set: { newValue in
            guard var current = store.note(with: note.id) else { return }
            current.body = newValue
            store.updateNote(current)
        }
    }
}

import SwiftUI
import SwiftData
import DayTrackerCore

/// Add a backfilled entry, or edit/delete an existing one.
struct EntryEditorView: View {
    enum Mode {
        case add
        case edit(LogEntry)
    }

    let mode: Mode

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Tracker> { $0.archived == false }, sort: \Tracker.sortOrder)
    private var trackers: [Tracker]

    @State private var tracker: Tracker?
    @State private var value: Double = 1
    @State private var occurredAt = Date.now
    @State private var note = ""
    @State private var didLoad = false

    private var isAdding: Bool {
        if case .add = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isAdding {
                        Picker("Tracker", selection: $tracker) {
                            Text("Choose…").tag(nil as Tracker?)
                            ForEach(trackers) { tracker in
                                Label(tracker.name, systemImage: tracker.icon).tag(tracker as Tracker?)
                            }
                        }
                    } else {
                        LabeledContent("Tracker", value: tracker?.name ?? "Unknown")
                    }
                    DatePicker("When", selection: $occurredAt, in: ...Date.now)
                }

                if let tracker, tracker.kind != .note {
                    Section("Value") {
                        valueEditor(for: tracker)
                    }
                }

                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                }

                if case .edit(let entry) = mode {
                    Section {
                        Button("Delete entry", role: .destructive) {
                            context.delete(entry)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isAdding ? "New entry" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(tracker == nil)
                }
            }
            .onAppear(perform: load)
            .onChange(of: tracker) { _, newTracker in
                if isAdding, let newTracker { value = defaultValue(for: newTracker) }
            }
        }
    }

    @ViewBuilder
    private func valueEditor(for tracker: Tracker) -> some View {
        switch tracker.kind {
        case .counter, .number:
            Stepper(value: $value, in: 0...100, step: tracker.defaultAmount) {
                Text(tracker.format(value))
            }
        case .dose:
            Picker("Dose", selection: $value) {
                Text("Taken").tag(1.0)
                Text("Skipped").tag(0.0)
            }
            .pickerStyle(.segmented)
        case .scale:
            ScaleGrid(range: tracker.scaleRange, selection: Int(value), color: tracker.color) {
                value = Double($0)
            }
            .padding(.vertical, 4)
        case .note:
            EmptyView()
        }
    }

    private func defaultValue(for tracker: Tracker) -> Double {
        switch tracker.kind {
        case .counter, .number: tracker.defaultAmount
        case .dose: 1
        case .scale: Double((tracker.scaleRange.lowerBound + tracker.scaleRange.upperBound) / 2)
        case .note: 0
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if case .edit(let entry) = mode {
            tracker = entry.tracker
            value = entry.value
            occurredAt = entry.occurredAt
            note = entry.note ?? ""
        }
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote = trimmed.isEmpty ? nil : trimmed
        switch mode {
        case .add:
            guard let tracker else { return }
            EntryLogger.log(tracker, value: value, at: occurredAt, note: finalNote, in: context)
        case .edit(let entry):
            entry.value = value
            entry.occurredAt = occurredAt
            entry.note = finalNote
        }
        dismiss()
    }
}

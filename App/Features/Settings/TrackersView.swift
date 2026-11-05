import SwiftUI
import SwiftData
import DayTrackerCore

/// Add, reorder, archive and restore trackers other than medicines (Phase 4).
struct TrackersView: View {
    static let kinds: [TrackerKind] = [.counter, .scale, .number, .note]

    @Environment(\.modelContext) private var context
    @Query(sort: \Tracker.sortOrder) private var trackers: [Tracker]
    @State private var isAdding = false
    @State private var pendingNew: Tracker?
    @State private var openNew: Tracker?

    var body: some View {
        let archived = trackers.filter { $0.archived && $0.kind != .dose }

        List {
            ForEach(Self.kinds, id: \.self) { kind in
                let active = trackers.filter { $0.kind == kind && !$0.archived }
                if !active.isEmpty {
                    Section(kind.sectionTitle) {
                        ForEach(active) { tracker in
                            NavigationLink {
                                TrackerDetailView(tracker: tracker)
                            } label: {
                                TrackerRow(tracker: tracker)
                            }
                            .deleteDisabled(!tracker.entries.isEmpty)
                        }
                        .onMove { source, destination in move(active, from: source, to: destination) }
                        .onDelete { offsets in
                            for index in offsets where active[index].entries.isEmpty {
                                context.delete(active[index])
                            }
                            try? context.save()
                        }
                    }
                }
            }

            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { tracker in
                        HStack {
                            TrackerRow(tracker: tracker)
                            Spacer()
                            Button("Restore") {
                                tracker.archived = false
                                try? context.save()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Section {
                EmptyView()
            } footer: {
                Text("Trackers with history can't be deleted, only archived from their page, so past data stays intact. Medicines are managed under Settings → Medicines.")
            }
        }
        .navigationTitle("Trackers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add tracker", systemImage: "plus") { isAdding = true }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $isAdding, onDismiss: {
            openNew = pendingNew
            pendingNew = nil
        }) {
            NewTrackerSheet { pendingNew = $0 }
        }
        .navigationDestination(item: $openNew) { tracker in
            TrackerDetailView(tracker: tracker)
        }
    }

    /// Reorders within one kind, reusing existing sort positions so other trackers keep their place.
    private func move(_ items: [Tracker], from source: IndexSet, to destination: Int) {
        let positions = items.map(\.sortOrder).sorted()
        var reordered = items
        reordered.move(fromOffsets: source, toOffset: destination)
        for (tracker, position) in zip(reordered, positions) {
            tracker.sortOrder = position
        }
        try? context.save()
    }
}

extension TrackerKind {
    var sectionTitle: String {
        switch self {
        case .counter: "Counters"
        case .scale: "Ratings"
        case .number: "Numbers"
        case .note: "Notes"
        case .dose: "Medicines"
        }
    }

    var displayName: String {
        switch self {
        case .counter: "Counter"
        case .scale: "Rating"
        case .number: "Number"
        case .note: "Note"
        case .dose: "Medicine"
        }
    }

    var explanation: String {
        switch self {
        case .counter: "Tap + to count, e.g. glasses of water, cigarettes, snacks."
        case .scale: "Rate how you feel, e.g. stress or pain, 1–10."
        case .number: "Enter a value, e.g. weight, steps, hours slept."
        case .note: "Write a few words, e.g. a journal line or symptoms."
        case .dose: "Taken or skipped, with optional reminders."
        }
    }
}

struct TrackerRow: View {
    let tracker: Tracker

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tracker.icon)
                .foregroundStyle(tracker.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(tracker.name)
                    .foregroundStyle(.primary)
                Text(tracker.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension Tracker {
    /// Short description for lists, e.g. "Counter · glasses" or "Rating 1–10".
    var summary: String {
        switch kind {
        case .counter:
            "Counter · +\(ValueFormat.amount(defaultAmount, singular: unit, plural: unitPlural)) per tap"
        case .scale:
            "Rating \(scaleRange.lowerBound)–\(scaleRange.upperBound)"
        case .number:
            unit.map { "Number · \($0)" } ?? "Number"
        case .note:
            "Note"
        case .dose:
            reminderTimes.isEmpty ? "As needed" : reminderTimes.map(\.display).joined(separator: ", ")
        }
    }
}

/// Kind, name and appearance; units and ranges are set on the tracker's page afterwards.
private struct NewTrackerSheet: View {
    let onCreate: (Tracker) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tracker.sortOrder, order: .reverse) private var trackers: [Tracker]

    @State private var kind: TrackerKind = .counter
    @State private var name = ""
    @State private var icon = "star.fill"
    @State private var colorName = "teal"

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kind", selection: $kind) {
                        ForEach(TrackersView.kinds, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(kind.explanation)
                }
                Section {
                    TextField("Name", text: $name)
                }
                Section("Appearance") {
                    AppearancePicker(icon: $icon, colorName: $colorName, icons: TrackerPalette.generalIcons)
                }
            }
            .navigationTitle("New tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func add() {
        let template = TrackerTemplate(
            name: trimmedName, kind: kind,
            unit: kind == .counter ? "time" : nil,
            unitPlural: kind == .counter ? "times" : nil,
            scaleRange: kind == .scale ? 1...10 : nil,
            icon: icon, color: colorName)
        let tracker = Tracker(template: template, sortOrder: (trackers.first?.sortOrder ?? 0) + 1)
        context.insert(tracker)
        try? context.save()
        onCreate(tracker)
        dismiss()
    }
}

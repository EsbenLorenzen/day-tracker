import SwiftUI
import SwiftData
import DayTrackerCore

/// Add, reorder, archive and restore medicines (Phase 2.5).
struct MedicinesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tracker.sortOrder) private var trackers: [Tracker]
    @State private var isAdding = false
    @State private var pendingNew: Tracker?
    @State private var openNew: Tracker?

    var body: some View {
        let active = trackers.filter { $0.kind == .dose && !$0.archived }
        let archived = trackers.filter { $0.kind == .dose && $0.archived }

        List {
            Section {
                ForEach(active) { tracker in
                    NavigationLink {
                        MedicineDetailView(tracker: tracker)
                    } label: {
                        MedicineRow(tracker: tracker)
                    }
                    // Only medicines without history can be deleted; others are archived.
                    .deleteDisabled(!tracker.entries.isEmpty)
                }
                .onMove { source, destination in move(active, from: source, to: destination) }
                .onDelete { offsets in
                    for index in offsets where active[index].entries.isEmpty {
                        context.delete(active[index])
                    }
                    changed()
                }
            } footer: {
                Text("Each medicine gets its own card on Today and its own reminders. Medicines with history can't be deleted, only archived from their page, so past data stays intact.")
            }

            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived) { tracker in
                        HStack {
                            MedicineRow(tracker: tracker)
                            Spacer()
                            Button("Restore") {
                                tracker.archived = false
                                changed()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .overlay {
            if active.isEmpty && archived.isEmpty {
                ContentUnavailableView(
                    "No medicines",
                    systemImage: "pills",
                    description: Text("Tap + to add one.")
                )
            }
        }
        .navigationTitle("Medicines")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add medicine", systemImage: "plus") { isAdding = true }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $isAdding, onDismiss: {
            // Open the new medicine's page (for reminder times) once the sheet is gone.
            openNew = pendingNew
            pendingNew = nil
        }) {
            NewMedicineSheet { pendingNew = $0 }
        }
        .navigationDestination(item: $openNew) { tracker in
            MedicineDetailView(tracker: tracker)
        }
    }

    /// Reorders medicines among themselves, reusing their existing sort positions
    /// so other trackers keep their place.
    private func move(_ medicines: [Tracker], from source: IndexSet, to destination: Int) {
        let positions = medicines.map(\.sortOrder).sorted()
        var reordered = medicines
        reordered.move(fromOffsets: source, toOffset: destination)
        for (tracker, position) in zip(reordered, positions) {
            tracker.sortOrder = position
        }
        changed()
    }

    private func changed() {
        try? context.save()
        Task { await NotificationScheduler.reschedule() }
    }
}

struct MedicineRow: View {
    let tracker: Tracker

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tracker.icon)
                .foregroundStyle(tracker.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(tracker.name)
                    .foregroundStyle(.primary)
                Text(tracker.reminderTimes.isEmpty
                     ? "As needed"
                     : tracker.reminderTimes.map(\.display).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Name and appearance for a new medicine; reminder times are added on its page afterwards.
private struct NewMedicineSheet: View {
    let onCreate: (Tracker) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tracker.sortOrder, order: .reverse) private var trackers: [Tracker]

    @State private var name = ""
    @State private var icon = "pills.fill"
    @State private var colorName = "red"

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Vitamin D", text: $name)
                }
                Section("Appearance") {
                    AppearancePicker(icon: $icon, colorName: $colorName)
                }
            }
            .navigationTitle("New medicine")
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
        let template = TrackerTemplate(name: trimmedName, kind: .dose, icon: icon, color: colorName)
        let tracker = Tracker(template: template, sortOrder: (trackers.first?.sortOrder ?? 0) + 1)
        context.insert(tracker)
        try? context.save()
        onCreate(tracker)
        dismiss()
    }
}

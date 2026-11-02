import SwiftUI
import SwiftData
import DayTrackerCore

struct HistoryView: View {
    @Query(sort: \LogEntry.occurredAt, order: .reverse) private var entries: [LogEntry]
    @Environment(\.modelContext) private var context
    @State private var editing: LogEntry?
    @State private var isAdding = false

    var body: some View {
        let days = AppConfig.dayBoundary.group(entries, calendar: .current) { $0.occurredAt }
        NavigationStack {
            List {
                ForEach(days) { group in
                    Section(title(for: group.day)) {
                        ForEach(group.items) { entry in
                            Button {
                                editing = entry
                            } label: {
                                EntryRow(entry: entry)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(group.items[index]) }
                        }
                    }
                }
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "list.bullet",
                        description: Text("Things you log on the Today tab show up here.")
                    )
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add entry", systemImage: "plus") { isAdding = true }
                }
            }
            .sheet(item: $editing) { entry in
                EntryEditorView(mode: .edit(entry))
            }
            .sheet(isPresented: $isAdding) {
                EntryEditorView(mode: .add)
            }
        }
    }

    private func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

private struct EntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.tracker?.icon ?? "questionmark.circle")
                .foregroundStyle(entry.tracker?.color ?? .secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.tracker?.name ?? "Unknown")
                    .foregroundStyle(.primary)
                if let note = entry.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(entry.tracker?.format(entry.value) ?? "")
                .foregroundStyle(.secondary)
            Text(entry.occurredAt.shortTime)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

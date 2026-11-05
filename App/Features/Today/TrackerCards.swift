import SwiftUI
import SwiftData
import DayTrackerCore

/// Water, coffee: big +1 button and today's total.
struct CounterCard: View {
    let tracker: Tracker
    /// Today's entries, oldest first.
    let entries: [LogEntry]

    @Environment(\.modelContext) private var context

    private var total: Double {
        if case .total(let total) = tracker.kind.aggregate(entries.map(\.loggedValue)) { return total }
        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: tracker.icon)
                    .font(.title2)
                    .foregroundStyle(tracker.color)
                Spacer()
                if let last = entries.last {
                    Menu {
                        Button("Undo last (\(last.occurredAt.shortTime))", systemImage: "arrow.uturn.backward",
                               role: .destructive) {
                            withAnimation { context.delete(last) }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(tracker.name)
                .font(.headline)
            Text(ValueFormat.amount(total, singular: tracker.unit, plural: tracker.unitPlural))
                .font(.title2.bold())
                .contentTransition(.numericText())
            Button {
                withAnimation {
                    _ = EntryLogger.log(tracker, value: tracker.defaultAmount, in: context)
                }
            } label: {
                Label("Add", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(tracker.color)
            .accessibilityLabel("Add \(tracker.unit ?? "one") of \(tracker.name.lowercased())")
        }
        .card()
        .sensoryFeedback(.increase, trigger: entryCount)
    }

    // Explicit Int: `trigger:` is generic, so a bare `entries.count` is ambiguous.
    private var entryCount: Int { entries.count }
}

/// Medicine: today's reminder slots, as-needed intake, and a "Taken" button (D11).
struct DoseCard: View {
    let tracker: Tracker
    let entries: [LogEntry]
    let day: DateInterval

    @Environment(\.modelContext) private var context

    private var taken: [LogEntry] { entries.filter { $0.value >= 1 } }

    /// Today's scheduled reminder times.
    private var slots: [Date] {
        tracker.reminderTimes
            .flatMap { RecurringTime(time: $0).occurrences(in: day, calendar: .current) }
            .sorted()
    }

    private func entry(for slot: Date) -> LogEntry? {
        entries.first { $0.scheduledFor == slot }
    }

    /// "Taken" fills the latest unanswered past slot; otherwise it's as-needed.
    private var openSlot: Date? {
        let now = Date.now
        return slots.last { $0 <= now && entry(for: $0) == nil }
    }

    private var slotSummary: String {
        let now = Date.now
        return slots.map { (slot: Date) -> String in
            switch entry(for: slot)?.value {
            case let value? where value >= 1: "\(slot.shortTime) ✓"
            case .some: "\(slot.shortTime) ✕"
            case nil: slot <= now ? "\(slot.shortTime) •" : slot.shortTime
            }
        }
        .joined(separator: "   ")
    }

    private var intakeSummary: String {
        let asNeeded = taken.filter { $0.scheduledFor == nil }
        if asNeeded.isEmpty { return slots.isEmpty ? "Not taken today" : "" }
        let times = asNeeded.map(\.occurredAt.shortTime).joined(separator: ", ")
        return slots.isEmpty ? "Taken at \(times)" : "Also taken at \(times)"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tracker.icon)
                .font(.title2)
                .foregroundStyle(tracker.color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(tracker.name)
                    .font(.headline)
                if !slots.isEmpty {
                    Text(slotSummary)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                let intake = intakeSummary
                if !intake.isEmpty {
                    Text(intake)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Taken") {
                withAnimation {
                    DoseRecorder.record(tracker, taken: true, slot: openSlot, source: .manual, in: context)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(tracker.color)
        }
        .card()
        .contextMenu {
            if let last = entries.last {
                Button("Undo last (\(last.occurredAt.shortTime))", systemImage: "arrow.uturn.backward",
                       role: .destructive) {
                    withAnimation { context.delete(last) }
                }
            }
        }
        .sensoryFeedback(.success, trigger: takenCount)
    }

    private var takenCount: Int { taken.count }
}

/// Mood, energy, focus: latest rating today; tap to rate.
struct ScaleCard: View {
    let tracker: Tracker
    let entries: [LogEntry]

    @Environment(\.modelContext) private var context
    @State private var isRating = false

    var body: some View {
        let latest = entries.last
        Button {
            isRating = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: tracker.icon)
                    .font(.title2)
                    .foregroundStyle(tracker.color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tracker.name)
                        .font(.headline)
                    Text(latest.map { "Last rated \($0.occurredAt.shortTime)" } ?? "Not rated yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let latest {
                    Text(ValueFormat.number(latest.value))
                        .font(.title.bold())
                        .foregroundStyle(tracker.color)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .card()
        .sheet(isPresented: $isRating) {
            NavigationStack {
                ScaleGrid(range: tracker.scaleRange, selection: nil, color: tracker.color) { value in
                    EntryLogger.log(tracker, value: Double(value), in: context)
                    isRating = false
                }
                .padding()
                .navigationTitle("\(tracker.name) right now")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isRating = false }
                    }
                }
            }
            .presentationDetents([.height(300)])
        }
    }
}

/// Numbers (weight, steps) and notes: latest value today; tap to add one.
struct ValueCard: View {
    let tracker: Tracker
    let entries: [LogEntry]

    @Environment(\.modelContext) private var context
    @State private var isAdding = false

    private var subtitle: String {
        guard let latest = entries.last else {
            return tracker.kind == .note ? "No note today" : "Nothing yet today"
        }
        if tracker.kind == .note {
            let count = entries.count
            return count == 1 ? "1 note today · \(latest.occurredAt.shortTime)"
                              : "\(count) notes today · last \(latest.occurredAt.shortTime)"
        }
        return "\(tracker.format(latest.value)) at \(latest.occurredAt.shortTime)"
    }

    var body: some View {
        Button {
            isAdding = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: tracker.icon)
                    .font(.title2)
                    .foregroundStyle(tracker.color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tracker.name)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(tracker.color)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .card()
        .contextMenu {
            if let last = entries.last {
                Button("Undo last (\(last.occurredAt.shortTime))", systemImage: "arrow.uturn.backward",
                       role: .destructive) {
                    withAnimation { context.delete(last) }
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            ValueEntrySheet(tracker: tracker, initialValue: entries.last?.value)
                .presentationDetents([.medium])
        }
    }
}

/// Enter a number or write a note.
private struct ValueEntrySheet: View {
    let tracker: Tracker
    let initialValue: Double?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double?
    @State private var note = ""
    @FocusState private var focused: Bool

    private var canSave: Bool {
        tracker.kind == .note
            ? !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : value != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if tracker.kind == .number {
                    Section {
                        TextField("Value", value: $value, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .focused($focused)
                    } footer: {
                        if let unit = tracker.unit { Text(unit) }
                    }
                    Section {
                        TextField("Note (optional)", text: $note, axis: .vertical)
                    }
                } else {
                    Section {
                        TextField("Write a note", text: $note, axis: .vertical)
                            .lineLimit(3...8)
                            .focused($focused)
                    }
                }
            }
            .navigationTitle(tracker.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if tracker.kind == .number { value = initialValue }
                focused = true
            }
        }
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        EntryLogger.log(tracker, value: value ?? 0, note: trimmed.isEmpty ? nil : trimmed, in: context)
        try? context.save()
        dismiss()
    }
}

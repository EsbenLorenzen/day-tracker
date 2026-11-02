import SwiftUI
import SwiftData
import DayTrackerCore

private extension View {
    func card() -> some View {
        padding()
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}

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

/// Medicine: "Taken" button and today's intake times (D11, as-needed use).
struct DoseCard: View {
    let tracker: Tracker
    let entries: [LogEntry]

    @Environment(\.modelContext) private var context

    private var taken: [LogEntry] { entries.filter { $0.value >= 1 } }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tracker.icon)
                .font(.title2)
                .foregroundStyle(tracker.color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(tracker.name)
                    .font(.headline)
                Text(taken.isEmpty
                     ? "Not taken today"
                     : "Taken at " + taken.map(\.occurredAt.shortTime).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Taken") {
                withAnimation {
                    _ = EntryLogger.log(tracker, value: 1, in: context)
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

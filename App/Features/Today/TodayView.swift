import SwiftUI
import SwiftData
import DayTrackerCore

struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date.now

    var body: some View {
        let day = AppConfig.dayBoundary.interval(containing: now, calendar: .current)
        NavigationStack {
            TodayContent(day: day)
                .navigationTitle("Today")
        }
        .onChange(of: scenePhase) { _, phase in
            // Roll over to the new day when coming back to the app.
            if phase == .active { now = .now }
        }
    }
}

private struct TodayContent: View {
    let day: DateInterval

    @Query(filter: #Predicate<Tracker> { $0.archived == false }, sort: \Tracker.sortOrder)
    private var trackers: [Tracker]
    @Query private var entries: [LogEntry]

    init(day: DateInterval) {
        self.day = day
        let start = day.start
        let end = day.end
        _entries = Query(
            filter: #Predicate<LogEntry> { $0.occurredAt >= start && $0.occurredAt < end },
            sort: \LogEntry.occurredAt
        )
    }

    var body: some View {
        let byTracker = Dictionary(grouping: entries) { $0.tracker?.persistentModelID }
        let todays = { (tracker: Tracker) in byTracker[tracker.persistentModelID] ?? [] }
        let counters = trackers.filter { $0.kind == .counter }
        let doses = trackers.filter { $0.kind == .dose }
        let scales = trackers.filter { $0.kind == .scale }

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(day.start, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !counters.isEmpty {
                    TodaySection(title: "Intake") {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                                  spacing: 12) {
                            ForEach(counters) { CounterCard(tracker: $0, entries: todays($0)) }
                        }
                    }
                }

                if !doses.isEmpty {
                    TodaySection(title: "Medicine") {
                        ForEach(doses) { DoseCard(tracker: $0, entries: todays($0)) }
                    }
                }

                if !scales.isEmpty {
                    TodaySection(title: "How are you?") {
                        ForEach(scales) { ScaleCard(tracker: $0, entries: todays($0)) }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct TodaySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            content
        }
    }
}

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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var schedules: [CheckInSchedule]
    @Query private var sessions: [CheckInSession]

    init(day: DateInterval) {
        self.day = day
        let start = day.start
        let end = day.end
        _entries = Query(
            filter: #Predicate<LogEntry> { $0.occurredAt >= start && $0.occurredAt < end },
            sort: \LogEntry.occurredAt
        )
        _sessions = Query(filter: #Predicate<CheckInSession> { $0.scheduledFor >= start && $0.scheduledFor < end })
    }

    var body: some View {
        let byTracker = Dictionary(grouping: entries) { $0.tracker?.persistentModelID }
        let todays = { (tracker: Tracker) in byTracker[tracker.persistentModelID] ?? [] }
        let counters = trackers.filter { $0.kind == .counter }
        let doses = trackers.filter { $0.kind == .dose }
        let scales = trackers.filter { $0.kind == .scale }
        let others = trackers.filter { $0.kind == .number || $0.kind == .note }
        // One column of counter cards at accessibility text sizes, so labels don't truncate.
        let counterColumns = dynamicTypeSize.isAccessibilitySize ? 1 : 2

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(day.start, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ReminderPermissionBanner()

                if schedules.contains(where: \.enabled) {
                    TodaySection(title: "Check-ins") {
                        TodayCheckIns(day: day, schedules: schedules, sessions: sessions)
                    }
                }

                if !counters.isEmpty {
                    TodaySection(title: "Intake") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: counterColumns),
                                  spacing: 12) {
                            ForEach(counters) { CounterCard(tracker: $0, entries: todays($0)) }
                        }
                    }
                }

                if !doses.isEmpty {
                    TodaySection(title: "Medicine") {
                        ForEach(doses) { DoseCard(tracker: $0, entries: todays($0), day: day) }
                    }
                }

                if !scales.isEmpty {
                    TodaySection(title: "How are you?") {
                        ForEach(scales) { ScaleCard(tracker: $0, entries: todays($0)) }
                    }
                }

                if !others.isEmpty {
                    TodaySection(title: "More") {
                        ForEach(others) { ValueCard(tracker: $0, entries: todays($0)) }
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

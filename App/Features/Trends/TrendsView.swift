import SwiftUI
import SwiftData
import Charts
import DayTrackerCore

/// 7- or 30-day charts per tracker (Phase 4). Serious analysis stays in Python (D09).
struct TrendsView: View {
    enum Period: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30
        var id: Int { rawValue }
        var title: String { self == .week ? "7 days" : "30 days" }
    }

    @Environment(\.scenePhase) private var scenePhase
    @State private var period: Period = .week
    @State private var now = Date.now

    var body: some View {
        NavigationStack {
            TrendsContent(period: period, now: now)
                .safeAreaInset(edge: .top) {
                    Picker("Period", selection: $period) {
                        ForEach(Period.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
                .navigationTitle("Trends")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = .now }
        }
    }
}

private struct TrendsContent: View {
    let period: TrendsView.Period
    let now: Date

    @Query(filter: #Predicate<Tracker> { $0.archived == false }, sort: \Tracker.sortOrder)
    private var trackers: [Tracker]
    @Query private var entries: [LogEntry]

    init(period: TrendsView.Period, now: Date) {
        self.period = period
        self.now = now
        // A day of margin before the range; the 04:00 boundary is applied in Trends.daily.
        let start = Calendar.current.date(byAdding: .day, value: -(period.rawValue + 1), to: now) ?? now
        _entries = Query(filter: #Predicate<LogEntry> { $0.occurredAt >= start })
    }

    var body: some View {
        let byTracker = Dictionary(grouping: entries) { $0.tracker?.persistentModelID }
        ScrollView {
            LazyVStack(spacing: 16) {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No data yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Charts appear here once you've logged a few days.")
                    )
                    .padding(.top, 40)
                }
                ForEach(trackers) { tracker in
                    let series = Trends.daily(
                        kind: tracker.kind,
                        values: (byTracker[tracker.persistentModelID] ?? []).map(\.loggedValue),
                        days: period.rawValue,
                        now: now,
                        boundary: AppConfig.dayBoundary,
                        calendar: .current
                    )
                    if series.contains(where: { ($0.value ?? 0) > 0 }) {
                        TrendCard(tracker: tracker, series: series, period: period)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct TrendCard: View {
    let tracker: Tracker
    let series: [DayValue]
    let period: TrendsView.Period

    private var summary: String {
        let average = Trends.average(series) ?? 0
        switch tracker.kind {
        case .scale:
            return "Average \(average.formatted(.number.precision(.fractionLength(1)))) of \(tracker.scaleRange.upperBound)"
        case .dose:
            let days = series.filter { ($0.value ?? 0) >= 1 }.count
            return "Taken on \(days) of \(series.count) days"
        case .note:
            let total = series.compactMap(\.value).reduce(0, +)
            return "\(ValueFormat.number(total)) notes"
        case .counter, .number:
            let perDay = average.formatted(.number.precision(.fractionLength(0...1)))
            let unit = tracker.unitPlural ?? tracker.unit
            return "Average \(perDay)\(unit.map { " \($0)" } ?? "") per day"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(tracker.name, systemImage: tracker.icon)
                    .font(.headline)
                    .foregroundStyle(tracker.color)
                Spacer()
            }
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            chart
                .frame(height: 140)
        }
        .card()
    }

    @ViewBuilder
    private var chart: some View {
        if tracker.kind == .scale {
            Chart(series.filter { $0.value != nil }, id: \.day) { point in
                LineMark(x: .value("Day", point.day, unit: .day), y: .value(tracker.name, point.value ?? 0))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tracker.color)
                PointMark(x: .value("Day", point.day, unit: .day), y: .value(tracker.name, point.value ?? 0))
                    .foregroundStyle(tracker.color)
            }
            .chartYScale(domain: Double(tracker.scaleRange.lowerBound)...Double(tracker.scaleRange.upperBound))
            .chartXScale(domain: xDomain)
            .chartXAxis { dayAxis }
        } else {
            Chart(series, id: \.day) { point in
                BarMark(x: .value("Day", point.day, unit: .day), y: .value(tracker.name, point.value ?? 0))
                    .foregroundStyle(tracker.color.gradient)
            }
            .chartXScale(domain: xDomain)
            .chartXAxis { dayAxis }
        }
    }

    private var xDomain: ClosedRange<Date> {
        let first = series.first?.day ?? .now
        let last = series.last?.day ?? .now
        return first...(Calendar.current.date(byAdding: .day, value: 1, to: last) ?? last)
    }

    private var dayAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 7)) { _ in
            AxisGridLine()
            AxisValueLabel(format: period == .week ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated))
        }
    }
}

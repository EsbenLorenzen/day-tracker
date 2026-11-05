import Foundation

/// One day's summarised value for a tracker. Nil = no data (ratings only; counts are 0).
public struct DayValue: Sendable, Equatable {
    public let day: Date
    public let value: Double?

    public init(day: Date, value: Double?) {
        self.day = day
        self.value = value
    }
}

public enum Trends {
    /// Daily values for the `days` days ending with the day that contains `now`, oldest first.
    /// Counters and numbers are summed, medicines count doses taken, ratings are averaged.
    public static func daily(
        kind: TrackerKind,
        values: [LoggedValue],
        days: Int,
        now: Date,
        boundary: DayBoundary,
        calendar: Calendar
    ) -> [DayValue] {
        guard days > 0 else { return [] }
        let today = boundary.dayStart(containing: now, calendar: calendar)
        let starts: [Date] = (0..<days).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        let byDay = Dictionary(grouping: values) { boundary.dayStart(containing: $0.occurredAt, calendar: calendar) }

        return starts.map { day in
            let aggregate = kind.aggregate(byDay[day] ?? [])
            return DayValue(day: day, value: aggregate.dailyValue)
        }
    }

    /// Mean of the days that have a value.
    public static func average(_ series: [DayValue]) -> Double? {
        let values = series.compactMap(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

extension DailyAggregate {
    /// The number charted for a day.
    public var dailyValue: Double? {
        switch self {
        case .total(let total): total
        case .doses(let taken, _): Double(taken)
        case .scale(_, let average, _): average
        case .notes(let count): Double(count)
        }
    }
}

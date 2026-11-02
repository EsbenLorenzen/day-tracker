import Foundation

/// Decides which "day" a moment belongs to (D14).
///
/// A day runs from `startHour` local time to `startHour` the next day, so a
/// coffee at 01:30 still counts towards the evening before.
public struct DayBoundary: Sendable, Equatable {
    public let startHour: Int

    public init(startHour: Int = 4) {
        precondition((0...23).contains(startHour), "startHour must be 0–23")
        self.startHour = startHour
    }

    /// Start of the day that contains `date`.
    public func dayStart(containing date: Date, calendar: Calendar) -> Date {
        let midnight = calendar.startOfDay(for: date)
        let start = boundary(onDayOf: midnight, calendar: calendar)
        if date >= start { return start }
        guard let previousMidnight = calendar.date(byAdding: .day, value: -1, to: midnight) else { return start }
        return boundary(onDayOf: previousMidnight, calendar: calendar)
    }

    /// The whole day containing `date`. Not always 24 h: DST changes make it 23 or 25 h.
    public func interval(containing date: Date, calendar: Calendar) -> DateInterval {
        let start = dayStart(containing: date, calendar: calendar)
        let midnight = calendar.startOfDay(for: start)
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: midnight) else {
            return DateInterval(start: start, duration: 86_400)
        }
        return DateInterval(start: start, end: boundary(onDayOf: nextMidnight, calendar: calendar))
    }

    /// Groups items by day, newest day first. Items keep their order within a day.
    public func group<Item>(
        _ items: [Item],
        calendar: Calendar,
        by dateOf: (Item) -> Date
    ) -> [DayGroup<Item>] {
        var buckets: [Date: [Item]] = [:]
        for item in items {
            buckets[dayStart(containing: dateOf(item), calendar: calendar), default: []].append(item)
        }
        return buckets.keys.sorted(by: >).map { DayGroup(day: $0, items: buckets[$0] ?? []) }
    }

    private func boundary(onDayOf midnight: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: midnight) ?? midnight
    }
}

public struct DayGroup<Item>: Identifiable {
    /// Start of the day (see `DayBoundary`).
    public let day: Date
    public let items: [Item]
    public var id: Date { day }

    public init(day: Date, items: [Item]) {
        self.day = day
        self.items = items
    }
}

extension DayGroup: Sendable where Item: Sendable {}
extension DayGroup: Equatable where Item: Equatable {}

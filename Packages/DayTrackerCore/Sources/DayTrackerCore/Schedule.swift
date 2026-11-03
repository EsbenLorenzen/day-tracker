import Foundation

/// A time of day, independent of date and time zone.
public struct ClockTime: Hashable, Comparable, Codable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    public init(minutesSinceMidnight minutes: Int) {
        let wrapped = ((minutes % 1440) + 1440) % 1440
        self.init(hour: wrapped / 60, minute: wrapped % 60)
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    /// "09:05". For identifiers and tests; the app formats for the user's locale.
    public var text: String {
        (hour < 10 ? "0" : "") + "\(hour):" + (minute < 10 ? "0" : "") + "\(minute)"
    }

    public static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

/// Set of weekdays, using `Calendar` numbering (1 = Sunday … 7 = Saturday).
public struct Weekdays: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue & 0b111_1111
    }

    public init(calendarWeekday weekday: Int) {
        self.init(rawValue: (1...7).contains(weekday) ? 1 << (weekday - 1) : 0)
    }

    public static let everyDay = Weekdays(rawValue: 0b111_1111)
    /// Monday–Friday.
    public static let workdays = Weekdays(rawValue: 0b011_1110)
    /// Saturday and Sunday.
    public static let weekend = Weekdays(rawValue: 0b100_0001)

    public func contains(calendarWeekday weekday: Int) -> Bool {
        contains(Weekdays(calendarWeekday: weekday)) && (1...7).contains(weekday)
    }

    public var calendarWeekdays: [Int] {
        (1...7).filter { contains(calendarWeekday: $0) }
    }
}

/// "At this time on these days", e.g. a check-in or a medicine reminder.
public struct RecurringTime: Hashable, Sendable {
    public var time: ClockTime
    public var days: Weekdays

    public init(time: ClockTime, days: Weekdays = .everyDay) {
        self.time = time
        self.days = days
    }

    /// All occurrences with `interval.start <= date < interval.end`, oldest first.
    public func occurrences(in interval: DateInterval, calendar: Calendar) -> [Date] {
        guard !days.isEmpty else { return [] }
        var result: [Date] = []
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            if days.contains(calendarWeekday: calendar.component(.weekday, from: day)),
               let date = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day),
               date >= interval.start, date < interval.end {
                result.append(date)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// The most recent occurrence at or before `date` (within the last week).
    public func latestOccurrence(atOrBefore date: Date, calendar: Calendar) -> Date? {
        let start = calendar.date(byAdding: .day, value: -8, to: date) ?? date
        return occurrences(in: DateInterval(start: start, end: date.addingTimeInterval(1)), calendar: calendar).last
    }
}

/// One repeating local notification trigger.
public struct PlannedTrigger: Hashable, Sendable {
    public var identifier: String
    public var hour: Int
    public var minute: Int
    /// Nil = every day.
    public var weekday: Int?
}

public enum NotificationPlanner {
    /// iOS keeps at most 64 pending local notifications per app.
    public static let pendingLimit = 64

    /// One trigger when every day is selected, otherwise one per weekday (D08).
    public static func triggers(idPrefix: String, recurring: RecurringTime) -> [PlannedTrigger] {
        let (hour, minute) = (recurring.time.hour, recurring.time.minute)
        if recurring.days == .everyDay {
            return [PlannedTrigger(identifier: "\(idPrefix).all", hour: hour, minute: minute, weekday: nil)]
        }
        return recurring.days.calendarWeekdays.map {
            PlannedTrigger(identifier: "\(idPrefix).w\($0)", hour: hour, minute: minute, weekday: $0)
        }
    }
}

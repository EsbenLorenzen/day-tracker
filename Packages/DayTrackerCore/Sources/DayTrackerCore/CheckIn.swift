import Foundation

/// State of one check-in occurrence (a `CheckInSession` in the app).
public enum CheckInStatus: String, Codable, CaseIterable, Sendable {
    /// Opened or created, nothing answered yet.
    case pending
    case answered
    case partial
    /// Explicitly skipped by the user.
    case skipped
    /// Never answered within the answer window.
    case missed

    /// Status after answering `answered` of `total` questions.
    public static func progress(answered: Int, total: Int) -> CheckInStatus {
        if answered <= 0 { return .pending }
        return answered >= total ? .answered : .partial
    }
}

public enum CheckInPolicy {
    /// How long after its scheduled time a check-in counts as "due" (D16).
    public static let answerWindow: TimeInterval = 3 * 3600
    /// How far back missed check-ins are filled in.
    public static let lookbackDays = 14

    public static func isDue(_ occurrence: Date, now: Date) -> Bool {
        occurrence <= now && now < occurrence.addingTimeInterval(answerWindow)
    }

    public static func isOverdue(_ occurrence: Date, now: Date) -> Bool {
        now >= occurrence.addingTimeInterval(answerWindow)
    }

    /// Occurrences since `since` whose answer window has passed and that have no session yet.
    public static func missedOccurrences(
        of recurring: RecurringTime,
        since: Date,
        now: Date,
        existing: Set<Date>,
        calendar: Calendar
    ) -> [Date] {
        let end = now.addingTimeInterval(-answerWindow)
        guard end > since else { return [] }
        return recurring.occurrences(in: DateInterval(start: since, end: end), calendar: calendar)
            .filter { !existing.contains($0) }
    }
}

public struct CheckInTemplate: Sendable, Equatable {
    public var name: String
    public var time: ClockTime
}

/// Check-ins created on first launch (D13).
public enum DefaultCheckIns {
    public static let all: [CheckInTemplate] = [
        CheckInTemplate(name: "Morning", time: ClockTime(hour: 9, minute: 0)),
        CheckInTemplate(name: "Afternoon", time: ClockTime(hour: 14, minute: 0)),
        CheckInTemplate(name: "Evening", time: ClockTime(hour: 21, minute: 0)),
    ]

    /// Default questions, matched against tracker names.
    public static let questionNames = ["Mood", "Energy", "Focus"]
}

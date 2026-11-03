import Foundation
import DayTrackerCore

enum NotificationCategory {
    static let checkIn = "CHECKIN"
    static let dose = "DOSE"
}

enum NotificationAction {
    static let taken = "TAKEN"
    static let skip = "SKIP"
    static let snooze = "SNOOZE"
}

/// What a notification is about, stored in its `userInfo`.
struct NotificationPayload: Sendable {
    enum Kind: String, Sendable {
        case checkIn
        case dose
    }

    enum Key {
        static let kind = "kind"
        static let target = "target"
        static let minutes = "minutes"
        static let scheduledFor = "scheduledFor"
    }

    var kind: Kind
    /// Schedule ID for check-ins, tracker ID for doses.
    var targetID: UUID
    /// Scheduled time of day, minutes since midnight.
    var minutes: Int
    /// Fixed slot, set on snoozed copies so the answer still counts for the original time.
    var scheduledFor: Date?

    init(kind: Kind, targetID: UUID, minutes: Int, scheduledFor: Date? = nil) {
        self.kind = kind
        self.targetID = targetID
        self.minutes = minutes
        self.scheduledFor = scheduledFor
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let kindRaw = userInfo[Key.kind] as? String,
              let kind = Kind(rawValue: kindRaw),
              let target = userInfo[Key.target] as? String,
              let targetID = UUID(uuidString: target),
              let minutes = userInfo[Key.minutes] as? Int
        else { return nil }
        self.kind = kind
        self.targetID = targetID
        self.minutes = minutes
        if let seconds = userInfo[Key.scheduledFor] as? Double {
            self.scheduledFor = Date(timeIntervalSince1970: seconds)
        }
    }

    var userInfo: [AnyHashable: Any] {
        var info: [AnyHashable: Any] = [
            Key.kind: kind.rawValue,
            Key.target: targetID.uuidString,
            Key.minutes: minutes,
        ]
        if let scheduledFor { info[Key.scheduledFor] = scheduledFor.timeIntervalSince1970 }
        return info
    }

    /// The occurrence this notification belongs to: the fixed slot, or the latest
    /// scheduled time at or before delivery (repeating triggers don't carry a date).
    func slot(deliveredAt: Date, calendar: Calendar = .current) -> Date {
        if let scheduledFor { return scheduledFor }
        let recurring = RecurringTime(time: ClockTime(minutesSinceMidnight: minutes))
        return recurring.latestOccurrence(atOrBefore: deliveredAt, calendar: calendar) ?? deliveredAt
    }
}

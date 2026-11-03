import Foundation
import SwiftData
import DayTrackerCore

/// When to ask what (D13). Questions are tracker IDs, in the order they're asked.
@Model
final class CheckInSchedule {
    var id: UUID = UUID()
    var name: String = "Check-in"
    var hour: Int = 9
    var minute: Int = 0
    /// `Weekdays` raw value; 127 = every day.
    var weekdayMask: Int = 127
    var trackerIDs: [UUID] = []
    var enabled: Bool = true
    var createdAt: Date = Date.now
    /// Missed check-ins are only filled in from here on, so editing the time doesn't create a backlog.
    var updatedAt: Date = Date.now

    init(name: String, time: ClockTime, days: Weekdays = .everyDay, trackerIDs: [UUID]) {
        self.name = name
        self.hour = time.hour
        self.minute = time.minute
        self.weekdayMask = days.rawValue
        self.trackerIDs = trackerIDs
    }

    var time: ClockTime {
        get { ClockTime(hour: hour, minute: minute) }
        set {
            hour = newValue.hour
            minute = newValue.minute
        }
    }

    var days: Weekdays {
        get { Weekdays(rawValue: weekdayMask) }
        set { weekdayMask = newValue.rawValue }
    }

    var recurring: RecurringTime {
        RecurringTime(time: time, days: days)
    }
}

import Foundation
import Testing
@testable import DayTrackerCore

@Suite struct ClockTimeTests {
    @Test func wrapsMinutes() {
        #expect(ClockTime(minutesSinceMidnight: 1500) == ClockTime(hour: 1, minute: 0))
        #expect(ClockTime(minutesSinceMidnight: -30) == ClockTime(hour: 23, minute: 30))
    }

    @Test func text() {
        #expect(ClockTime(hour: 9, minute: 5).text == "09:05")
        #expect(ClockTime(hour: 21, minute: 30).text == "21:30")
    }
}

@Suite struct WeekdaysTests {
    @Test func workdays() {
        #expect(Weekdays.workdays.calendarWeekdays == [2, 3, 4, 5, 6])
        #expect(!Weekdays.workdays.contains(calendarWeekday: 1))
    }

    @Test func weekend() {
        #expect(Weekdays.weekend.calendarWeekdays == [1, 7])
    }

    @Test func invalidWeekdayIsIgnored() {
        #expect(Weekdays(calendarWeekday: 9).isEmpty)
    }
}

@Suite struct RecurringTimeTests {
    @Test func workdayOccurrencesInAWeek() throws {
        // 2026-11-01 is a Sunday.
        let cal = try calendar("Europe/Copenhagen")
        let start = try date(cal, 2026, 11, 1, 0)
        let end = try date(cal, 2026, 11, 8, 0)
        let firstExpected = try date(cal, 2026, 11, 2, 9)
        let recurring = RecurringTime(time: ClockTime(hour: 9, minute: 0), days: .workdays)
        let occurrences = recurring.occurrences(in: DateInterval(start: start, end: end), calendar: cal)
        #expect(occurrences.count == 5)
        #expect(occurrences.first == firstExpected)
    }

    @Test func occurrenceAtIntervalEndIsExcluded() throws {
        let cal = try calendar("Europe/Copenhagen")
        let start = try date(cal, 2026, 11, 2, 0)
        let end = try date(cal, 2026, 11, 2, 9)
        let recurring = RecurringTime(time: ClockTime(hour: 9, minute: 0))
        #expect(recurring.occurrences(in: DateInterval(start: start, end: end), calendar: cal).isEmpty)
    }

    @Test func latestOccurrence() throws {
        let cal = try calendar("Europe/Copenhagen")
        let recurring = RecurringTime(time: ClockTime(hour: 9, minute: 0))
        let nineToday = try date(cal, 2026, 11, 2, 9)
        let nineYesterday = try date(cal, 2026, 11, 1, 9)
        let justAfter = nineToday.addingTimeInterval(0.5)
        let justBefore = nineToday.addingTimeInterval(-60)
        #expect(recurring.latestOccurrence(atOrBefore: nineToday, calendar: cal) == nineToday)
        #expect(recurring.latestOccurrence(atOrBefore: justAfter, calendar: cal) == nineToday)
        #expect(recurring.latestOccurrence(atOrBefore: justBefore, calendar: cal) == nineYesterday)
    }
}

@Suite struct NotificationPlannerTests {
    @Test func everyDayIsOneTrigger() {
        let triggers = NotificationPlanner.triggers(
            idPrefix: "checkin.x", recurring: RecurringTime(time: ClockTime(hour: 9, minute: 0)))
        #expect(triggers == [PlannedTrigger(identifier: "checkin.x.all", hour: 9, minute: 0, weekday: nil)])
    }

    @Test func someDaysAreOneTriggerEach() {
        let triggers = NotificationPlanner.triggers(
            idPrefix: "p", recurring: RecurringTime(time: ClockTime(hour: 14, minute: 30), days: .workdays))
        #expect(triggers.map(\.weekday) == [2, 3, 4, 5, 6])
        #expect(triggers.map(\.identifier).first == "p.w2")
    }

    @Test func noDaysNoTriggers() {
        let triggers = NotificationPlanner.triggers(
            idPrefix: "p", recurring: RecurringTime(time: ClockTime(hour: 9, minute: 0), days: []))
        #expect(triggers.isEmpty)
    }
}

@Suite struct CheckInPolicyTests {
    @Test func progressStatus() {
        #expect(CheckInStatus.progress(answered: 0, total: 3) == .pending)
        #expect(CheckInStatus.progress(answered: 2, total: 3) == .partial)
        #expect(CheckInStatus.progress(answered: 3, total: 3) == .answered)
    }

    @Test func dueWithinWindow() throws {
        let cal = try calendar("Europe/Copenhagen")
        let nine = try date(cal, 2026, 11, 2, 9)
        #expect(CheckInPolicy.isDue(nine, now: nine.addingTimeInterval(3600)))
        #expect(!CheckInPolicy.isDue(nine, now: nine.addingTimeInterval(-60)))
        #expect(CheckInPolicy.isOverdue(nine, now: nine.addingTimeInterval(3 * 3600)))
    }

    @Test func missedSkipsExistingAndStillDue() throws {
        let cal = try calendar("Europe/Copenhagen")
        let recurring = RecurringTime(time: ClockTime(hour: 9, minute: 0))
        let since = try date(cal, 2026, 11, 1, 0)
        let now = try date(cal, 2026, 11, 3, 10)  // Nov 3 09:00 is still due
        let nov1 = try date(cal, 2026, 11, 1, 9)
        let nov2 = try date(cal, 2026, 11, 2, 9)
        let missed = CheckInPolicy.missedOccurrences(
            of: recurring, since: since, now: now, existing: [nov1], calendar: cal)
        #expect(missed == [nov2])
    }

    @Test func defaultCheckIns() {
        #expect(DefaultCheckIns.all.map(\.time.text) == ["09:00", "14:00", "21:00"])
        let trackerNames = Set(DefaultTrackers.all.map(\.name))
        #expect(DefaultCheckIns.questionNames.allSatisfy { trackerNames.contains($0) })
    }
}

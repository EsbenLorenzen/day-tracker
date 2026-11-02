import Foundation
import Testing
@testable import DayTrackerCore

private func calendar(_ identifier: String) throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: identifier))
    return calendar
}

private func date(
    _ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0
) throws -> Date {
    try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
}

@Suite struct DayBoundaryTests {
    let boundary = DayBoundary(startHour: 4)

    @Test func beforeStartHourBelongsToPreviousDay() throws {
        let cal = try calendar("Europe/Copenhagen")
        let lateNight = try date(cal, 2026, 11, 2, 3, 59)
        let expected = try date(cal, 2026, 11, 1, 4)
        #expect(boundary.dayStart(containing: lateNight, calendar: cal) == expected)
    }

    @Test func startHourBeginsNewDay() throws {
        let cal = try calendar("Europe/Copenhagen")
        let morning = try date(cal, 2026, 11, 2, 4)
        #expect(boundary.dayStart(containing: morning, calendar: cal) == morning)
    }

    @Test func midnightBoundary() throws {
        let cal = try calendar("Europe/Copenhagen")
        let justAfter = try date(cal, 2026, 11, 2, 0, 1)
        let midnight = try date(cal, 2026, 11, 2, 0)
        #expect(DayBoundary(startHour: 0).dayStart(containing: justAfter, calendar: cal) == midnight)
    }

    @Test func dayWithSpringForwardIs23Hours() throws {
        // Copenhagen skips 02:00–03:00 on 2026-03-29, inside the day starting 03-28 04:00.
        let cal = try calendar("Europe/Copenhagen")
        let noon = try date(cal, 2026, 3, 28, 12)
        let expectedStart = try date(cal, 2026, 3, 28, 4)
        let expectedEnd = try date(cal, 2026, 3, 29, 4)
        let interval = boundary.interval(containing: noon, calendar: cal)
        #expect(interval.start == expectedStart)
        #expect(interval.end == expectedEnd)
        #expect(interval.duration == 23 * 3600)
    }

    @Test func normalDayIs24Hours() throws {
        let cal = try calendar("Europe/Copenhagen")
        let noon = try date(cal, 2026, 11, 2, 12)
        let interval = boundary.interval(containing: noon, calendar: cal)
        #expect(interval.duration == 24 * 3600)
    }

    @Test func groupsNewestDayFirstKeepingOrder() throws {
        let cal = try calendar("Europe/Copenhagen")
        let items = [
            try date(cal, 2026, 11, 1, 9),
            try date(cal, 2026, 11, 2, 1),  // still Nov 1
            try date(cal, 2026, 11, 2, 9),
            try date(cal, 2026, 11, 2, 10),
        ]
        let nov2 = try date(cal, 2026, 11, 2, 4)
        let groups = boundary.group(items, calendar: cal) { $0 }
        try #require(groups.count == 2)
        #expect(groups[0].day == nov2)
        #expect(groups[0].items == [items[2], items[3]])
        #expect(groups[1].items == [items[0], items[1]])
    }
}

@Suite struct AggregationTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func counterSums() {
        let values = [1.0, 1, 2].map { LoggedValue(value: $0, occurredAt: t0) }
        #expect(TrackerKind.counter.aggregate(values) == .total(4))
    }

    @Test func dosesCountTakenAndSkipped() {
        let values = [1.0, 0, 1].map { LoggedValue(value: $0, occurredAt: t0) }
        #expect(TrackerKind.dose.aggregate(values) == .doses(taken: 2, skipped: 1))
    }

    @Test func scaleLatestIsByTimeNotOrder() {
        let values = [
            LoggedValue(value: 8, occurredAt: t0.addingTimeInterval(3600)),
            LoggedValue(value: 4, occurredAt: t0),
        ]
        #expect(TrackerKind.scale.aggregate(values) == .scale(latest: 8, average: 6, count: 2))
    }

    @Test func emptyScale() {
        #expect(TrackerKind.scale.aggregate([]) == .scale(latest: nil, average: nil, count: 0))
    }
}

@Suite struct DefaultTrackersTests {
    @Test func namesAreUnique() {
        let names = DefaultTrackers.all.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test func statesAreOneToTenScales() {
        for name in ["Mood", "Energy", "Focus"] {
            let tracker = DefaultTrackers.all.first { $0.name == name }
            #expect(tracker?.kind == .scale)
            #expect(tracker?.scaleRange == 1...10)
        }
    }
}

@Suite struct ValueFormatTests {
    @Test(arguments: [
        (0.0, "0 glasses"),
        (1.0, "1 glass"),
        (3.0, "3 glasses"),
        (1.5, "1.5 glasses"),
    ])
    func pluralises(value: Double, expected: String) {
        #expect(ValueFormat.amount(value, singular: "glass", plural: "glasses") == expected)
    }

    @Test func withoutUnit() {
        #expect(ValueFormat.amount(2, singular: nil, plural: nil) == "2")
    }
}

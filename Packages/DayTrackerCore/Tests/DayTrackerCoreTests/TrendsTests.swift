import Foundation
import Testing
@testable import DayTrackerCore

@Suite struct TrendsTests {
    let boundary = DayBoundary(startHour: 4)

    @Test func countersFillZeroAndUseDayBoundary() throws {
        let cal = try calendar("Europe/Copenhagen")
        let now = try date(cal, 2026, 11, 5, 12)
        let values = [
            LoggedValue(value: 1, occurredAt: try date(cal, 2026, 11, 3, 10)),
            LoggedValue(value: 1, occurredAt: try date(cal, 2026, 11, 4, 2)),  // still Nov 3
            LoggedValue(value: 2, occurredAt: try date(cal, 2026, 11, 5, 9)),
        ]
        let series = Trends.daily(kind: .counter, values: values, days: 4, now: now, boundary: boundary, calendar: cal)
        let firstDay = try date(cal, 2026, 11, 2, 4)
        #expect(series.map(\.value) == [0, 2, 0, 2])
        #expect(series.first?.day == firstDay)
    }

    @Test func ratingsAverageAndLeaveGaps() throws {
        let cal = try calendar("Europe/Copenhagen")
        let now = try date(cal, 2026, 11, 5, 12)
        let values = [
            LoggedValue(value: 4, occurredAt: try date(cal, 2026, 11, 5, 9)),
            LoggedValue(value: 8, occurredAt: try date(cal, 2026, 11, 5, 21)),
        ]
        let series = Trends.daily(kind: .scale, values: values, days: 3, now: now, boundary: boundary, calendar: cal)
        #expect(series.map(\.value) == [nil, nil, 6])
        #expect(Trends.average(series) == 6)
    }

    @Test func dosesCountTaken() throws {
        let cal = try calendar("Europe/Copenhagen")
        let now = try date(cal, 2026, 11, 5, 12)
        let values = [
            LoggedValue(value: 1, occurredAt: try date(cal, 2026, 11, 5, 8)),
            LoggedValue(value: 0, occurredAt: try date(cal, 2026, 11, 5, 20)),
        ]
        let series = Trends.daily(kind: .dose, values: values, days: 1, now: now, boundary: boundary, calendar: cal)
        #expect(series.map(\.value) == [1])
    }

    @Test func daysKeepStartHourAcrossDST() throws {
        // Copenhagen leaves summer time on 2026-10-25.
        let cal = try calendar("Europe/Copenhagen")
        let now = try date(cal, 2026, 10, 27, 12)
        let series = Trends.daily(kind: .counter, values: [], days: 5, now: now, boundary: boundary, calendar: cal)
        let hours = series.map { cal.component(.hour, from: $0.day) }
        #expect(hours == [4, 4, 4, 4, 4])
    }

    @Test func emptyAverage() {
        #expect(Trends.average([]) == nil)
    }
}

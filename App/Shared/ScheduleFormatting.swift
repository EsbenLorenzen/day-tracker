import Foundation
import SwiftUI
import DayTrackerCore

extension ClockTime {
    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    func date(on day: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    /// Formatted for the user's locale (12/24 h).
    var display: String { date().shortTime }
}

extension Weekdays {
    /// Calendar weekdays in display order, starting at the locale's first weekday.
    static func ordered(calendar: Calendar = .current) -> [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    func summary(calendar: Calendar = .current) -> String {
        if self == .everyDay { return "Every day" }
        if self == .workdays { return "Weekdays" }
        if self == .weekend { return "Weekends" }
        if isEmpty { return "No days" }
        return Self.ordered(calendar: calendar)
            .filter { contains(calendarWeekday: $0) }
            .map { calendar.shortWeekdaySymbols[$0 - 1] }
            .joined(separator: ", ")
    }
}

extension View {
    /// Rounded card on the grouped background.
    func card() -> some View {
        padding()
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}

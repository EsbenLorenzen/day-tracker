import Foundation
import SwiftData
import DayTrackerCore

/// One thing that happened: a glass of water, a dose, a mood rating (D07).
@Model
final class LogEntry {
    var id: UUID = UUID()
    var tracker: Tracker?
    var value: Double = 0
    /// When it happened; editable for backfilling.
    var occurredAt: Date = Date.now
    /// When it was recorded.
    var loggedAt: Date = Date.now
    /// Time zone at logging time, so time-of-day analysis stays right when travelling.
    var timeZoneID: String = TimeZone.current.identifier
    var sourceRaw: String = EntrySource.manual.rawValue
    var note: String?
    /// For scheduled doses: the reminder slot this answers (D11). Nil = as-needed.
    var scheduledFor: Date?

    init(value: Double, occurredAt: Date, source: EntrySource, note: String?) {
        self.value = value
        self.occurredAt = occurredAt
        self.sourceRaw = source.rawValue
        self.note = note
    }

    var source: EntrySource {
        EntrySource(rawValue: sourceRaw) ?? .manual
    }

    var loggedValue: LoggedValue {
        LoggedValue(value: value, occurredAt: occurredAt)
    }
}

@MainActor
enum EntryLogger {
    /// Inserts before linking the tracker; SwiftData requires both sides to be in the context.
    @discardableResult
    static func log(
        _ tracker: Tracker,
        value: Double,
        at date: Date = .now,
        source: EntrySource = .manual,
        note: String? = nil,
        in context: ModelContext
    ) -> LogEntry {
        let entry = LogEntry(value: value, occurredAt: date, source: source, note: note)
        context.insert(entry)
        entry.tracker = tracker
        return entry
    }
}

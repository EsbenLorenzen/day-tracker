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
    /// Set when answered as part of a check-in (`CheckInSession.id`).
    var sessionID: UUID?

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

@MainActor
enum DoseRecorder {
    /// Records taken/skipped. With a slot, updates that slot's entry instead of adding a second one.
    static func record(_ tracker: Tracker, taken: Bool, slot: Date?, source: EntrySource, in context: ModelContext) {
        let value: Double = taken ? 1 : 0
        if let slot, let existing = tracker.entries.first(where: { $0.scheduledFor == slot }) {
            existing.value = value
            existing.occurredAt = .now
            existing.sourceRaw = source.rawValue
            return
        }
        let entry = EntryLogger.log(tracker, value: value, source: source, in: context)
        entry.scheduledFor = slot
    }
}

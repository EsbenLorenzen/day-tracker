import Foundation

/// Turns a `Backup` into the export files (D17): tidy CSVs for analysis plus the JSON backup.
public enum Exporter {
    public static let entriesFileName = "entries.csv"
    public static let trackersFileName = "trackers.csv"
    public static let checkInsFileName = "checkins.csv"
    public static let backupFileName = "backup.json"
    public static let readmeFileName = "README.txt"

    /// One `.zip` with all export files.
    public static func archive(_ backup: Backup, timeZone: TimeZone, dayBoundary: DayBoundary) throws -> Data {
        let files: [(name: String, data: Data)] = [
            (entriesFileName, Data(entriesCSV(backup, dayBoundary: dayBoundary).utf8)),
            (trackersFileName, Data(trackersCSV(backup).utf8)),
            (checkInsFileName, Data(checkInsCSV(backup, timeZone: timeZone, dayBoundary: dayBoundary).utf8)),
            (backupFileName, try backup.encodedJSON()),
            (readmeFileName, Data(readme.utf8)),
        ]
        return StoredZip.archive(files, modified: backup.exportedAt)
    }

    /// One row per entry, oldest first. Times are in the entry's own time zone, with offset.
    public static func entriesCSV(_ backup: Backup, dayBoundary: DayBoundary) -> String {
        let trackers = Dictionary(backup.trackers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var formatter = TimeFormatter()
        var rows = [[
            "entry_id", "tracker_id", "tracker_name", "kind", "value", "unit", "occurred_at", "logged_at",
            "time_zone", "day", "source", "session_id", "scheduled_for", "note",
        ]]
        for entry in backup.entries.sorted(by: { $0.occurredAt < $1.occurredAt }) {
            let tracker = entry.trackerID.flatMap { trackers[$0] }
            let zone = entry.timeZoneID
            rows.append([
                entry.id.uuidString,
                entry.trackerID?.uuidString ?? "",
                tracker?.name ?? "",
                tracker?.kind.rawValue ?? "",
                ValueFormat.number(entry.value),
                tracker?.unit ?? "",
                formatter.timestamp(entry.occurredAt, zone: zone),
                formatter.timestamp(entry.loggedAt, zone: zone),
                zone,
                formatter.day(of: entry.occurredAt, zone: zone, boundary: dayBoundary),
                entry.source.rawValue,
                entry.sessionID?.uuidString ?? "",
                entry.scheduledFor.map { formatter.timestamp($0, zone: zone) } ?? "",
                entry.note ?? "",
            ])
        }
        return CSV.document(rows)
    }

    public static func trackersCSV(_ backup: Backup) -> String {
        var rows = [[
            "tracker_id", "name", "kind", "unit", "unit_plural", "scale_min", "scale_max", "icon", "color",
            "sort_order", "archived", "reminder_times",
        ]]
        for tracker in backup.trackers.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            rows.append([
                tracker.id.uuidString,
                tracker.name,
                tracker.kind.rawValue,
                tracker.unit ?? "",
                tracker.unitPlural ?? "",
                tracker.scaleMin.map { String($0) } ?? "",
                tracker.scaleMax.map { String($0) } ?? "",
                tracker.icon,
                tracker.color,
                String(tracker.sortOrder),
                tracker.archived ? "true" : "false",
                tracker.reminderMinutes.sorted()
                    .map { ClockTime(minutesSinceMidnight: $0).text }
                    .joined(separator: ";"),
            ])
        }
        return CSV.document(rows)
    }

    /// One row per check-in occurrence. Sessions have no stored time zone, so `timeZone` is used.
    public static func checkInsCSV(_ backup: Backup, timeZone: TimeZone, dayBoundary: DayBoundary) -> String {
        let names = Dictionary(backup.schedules.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let zone = timeZone.identifier
        var formatter = TimeFormatter()
        var rows = [[
            "session_id", "schedule_id", "schedule_name", "scheduled_for", "day", "status",
            "question_count", "answered_count", "opened_at", "completed_at",
        ]]
        for session in backup.sessions.sorted(by: { $0.scheduledFor < $1.scheduledFor }) {
            rows.append([
                session.id.uuidString,
                session.scheduleID.uuidString,
                names[session.scheduleID] ?? "",
                formatter.timestamp(session.scheduledFor, zone: zone),
                formatter.day(of: session.scheduledFor, zone: zone, boundary: dayBoundary),
                session.status.rawValue,
                String(session.questionCount),
                String(session.answeredCount),
                session.openedAt.map { formatter.timestamp($0, zone: zone) } ?? "",
                session.completedAt.map { formatter.timestamp($0, zone: zone) } ?? "",
            ])
        }
        return CSV.document(rows)
    }

    public static let readme = """
        DayTracker export

        entries.csv   One row per logged thing (water, coffee, medicine, ratings).
                      occurred_at is local time with UTC offset; day uses a 04:00 day boundary.
        trackers.csv  What can be logged; reminder_times are daily medicine reminders.
        checkins.csv  One row per check-in occurrence with its status.
        backup.json   Everything, for restoring into the app (Settings → Data → Import backup).

        Analyse with analysis/daytracker.py in the DayTracker repository.

        """
}

/// RFC 4180-style CSV with "\\n" line endings.
enum CSV {
    static func document(_ rows: [[String]]) -> String {
        rows.map { $0.map(field).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// ISO 8601 timestamps and day strings per time zone, with cached formatters.
private struct TimeFormatter {
    private var formatters: [String: ISO8601DateFormatter] = [:]

    mutating func timestamp(_ date: Date, zone: String) -> String {
        if let formatter = formatters[zone] { return formatter.string(from: date) }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: zone) ?? .current
        formatters[zone] = formatter
        return formatter.string(from: date)
    }

    func day(of date: Date, zone: String, boundary: DayBoundary) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .current
        let start = boundary.dayStart(containing: date, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day], from: start)
        return "\(parts.year ?? 0)-\(pad(parts.month ?? 0))-\(pad(parts.day ?? 0))"
    }

    private func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

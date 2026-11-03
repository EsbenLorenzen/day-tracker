import Foundation
import SwiftData
import DayTrackerCore

/// Builds the export `.zip` from everything in the database (D17).
@MainActor
enum DataExport {
    static func backup(from context: ModelContext, now: Date = .now) -> Backup {
        let trackers = (try? context.fetch(FetchDescriptor<Tracker>())) ?? []
        let entries = (try? context.fetch(FetchDescriptor<LogEntry>())) ?? []
        let schedules = (try? context.fetch(FetchDescriptor<CheckInSchedule>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<CheckInSession>())) ?? []
        return Backup(
            exportedAt: now,
            trackers: trackers.map { TrackerRecord($0) },
            entries: entries.map { EntryRecord($0) },
            schedules: schedules.map { ScheduleRecord($0) },
            sessions: sessions.map { SessionRecord($0) }
        )
    }

    /// Writes `DayTracker-<date>-<time>.zip` to a temporary folder and returns its URL.
    static func writeArchive(from context: ModelContext, now: Date = .now) throws -> URL {
        let data = try Exporter.archive(
            backup(from: context, now: now), timeZone: .current, dayBoundary: AppConfig.dayBoundary)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let url = folder.appendingPathComponent("DayTracker-\(formatter.string(from: now)).zip")
        try data.write(to: url, options: .atomic)
        return url
    }
}

extension TrackerRecord {
    init(_ tracker: Tracker) {
        self.init(
            id: tracker.id, name: tracker.name, kind: tracker.kind, unit: tracker.unit,
            unitPlural: tracker.unitPlural, defaultAmount: tracker.defaultAmount,
            scaleMin: tracker.scaleMin, scaleMax: tracker.scaleMax, icon: tracker.icon,
            color: tracker.colorName, sortOrder: tracker.sortOrder, archived: tracker.archived,
            createdAt: tracker.createdAt, reminderMinutes: tracker.reminderMinutes)
    }
}

extension EntryRecord {
    init(_ entry: LogEntry) {
        self.init(
            id: entry.id, trackerID: entry.tracker?.id, value: entry.value, occurredAt: entry.occurredAt,
            loggedAt: entry.loggedAt, timeZoneID: entry.timeZoneID, source: entry.source, note: entry.note,
            scheduledFor: entry.scheduledFor, sessionID: entry.sessionID)
    }
}

extension ScheduleRecord {
    init(_ schedule: CheckInSchedule) {
        self.init(
            id: schedule.id, name: schedule.name, hour: schedule.hour, minute: schedule.minute,
            weekdayMask: schedule.weekdayMask, trackerIDs: schedule.trackerIDs, enabled: schedule.enabled,
            createdAt: schedule.createdAt, updatedAt: schedule.updatedAt)
    }
}

extension SessionRecord {
    init(_ session: CheckInSession) {
        self.init(
            id: session.id, scheduleID: session.scheduleID, scheduledFor: session.scheduledFor,
            openedAt: session.openedAt, completedAt: session.completedAt, status: session.status,
            questionCount: session.questionCount, answeredCount: session.answeredCount)
    }
}

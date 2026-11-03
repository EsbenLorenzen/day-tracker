import Foundation
import SwiftData
import DayTrackerCore

/// Merges a backup into the database (D17). Adds what's missing, never deletes or overwrites.
@MainActor
enum DataImport {
    struct Summary {
        var trackers = 0
        var entries = 0
        var schedules = 0
        var sessions = 0

        var text: String {
            if trackers + entries + schedules + sessions == 0 {
                return "Nothing new – everything in the backup is already on this phone."
            }
            return "Added \(entries) entries, \(trackers) trackers, \(schedules) check-ins and \(sessions) check-in records."
        }
    }

    static func run(_ backup: Backup, into context: ModelContext) -> Summary {
        var summary = Summary()
        let backupTrackerIDs = Set(backup.trackers.map(\.id))
        let backupScheduleIDs = Set(backup.schedules.map(\.id))

        // Trackers. A fresh install has its own default trackers with new IDs; an unused default
        // with the same name and kind takes over the backed-up tracker's ID instead of duplicating it.
        var trackers = Dictionary(
            ((try? context.fetch(FetchDescriptor<Tracker>())) ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first })
        var renamedIDs: [UUID: UUID] = [:]
        for record in backup.trackers where trackers[record.id] == nil {
            if let placeholder = trackers.values.first(where: {
                $0.name == record.name && $0.kind == record.kind && $0.entries.isEmpty
                    && !backupTrackerIDs.contains($0.id)
            }) {
                trackers.removeValue(forKey: placeholder.id)
                renamedIDs[placeholder.id] = record.id
                placeholder.apply(record)
                trackers[record.id] = placeholder
            } else {
                let tracker = Tracker(record: record)
                context.insert(tracker)
                trackers[record.id] = tracker
                summary.trackers += 1
            }
        }

        // Check-in schedules, adopting unedited defaults the same way.
        var schedules = Dictionary(
            ((try? context.fetch(FetchDescriptor<CheckInSchedule>())) ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first })
        for schedule in schedules.values {
            schedule.trackerIDs = schedule.trackerIDs.map { renamedIDs[$0] ?? $0 }
        }
        for record in backup.schedules where schedules[record.id] == nil {
            if let placeholder = schedules.values.first(where: {
                $0.name == record.name && $0.hour == record.hour && $0.minute == record.minute
                    && !backupScheduleIDs.contains($0.id)
            }) {
                schedules.removeValue(forKey: placeholder.id)
                placeholder.apply(record)
                schedules[record.id] = placeholder
            } else {
                let schedule = CheckInSchedule(record: record)
                context.insert(schedule)
                schedules[record.id] = schedule
                summary.schedules += 1
            }
        }

        // Entries, by ID.
        let entryIDs = Set(((try? context.fetch(FetchDescriptor<LogEntry>())) ?? []).map(\.id))
        for record in backup.entries where !entryIDs.contains(record.id) {
            let entry = LogEntry(record: record)
            context.insert(entry)
            entry.tracker = record.trackerID.flatMap { trackers[$0] }
            summary.entries += 1
        }

        // Check-in sessions, by ID and by occurrence (schedule + time).
        let existingSessions = (try? context.fetch(FetchDescriptor<CheckInSession>())) ?? []
        let sessionIDs = Set(existingSessions.map(\.id))
        let occurrences = Set(existingSessions.map { "\($0.scheduleID)|\($0.scheduledFor.timeIntervalSince1970)" })
        for record in backup.sessions
        where !sessionIDs.contains(record.id)
            && !occurrences.contains("\(record.scheduleID)|\(record.scheduledFor.timeIntervalSince1970)") {
            context.insert(CheckInSession(record: record))
            summary.sessions += 1
        }

        try? context.save()
        return summary
    }
}

extension Tracker {
    convenience init(record: TrackerRecord) {
        self.init(template: TrackerTemplate(name: record.name, kind: record.kind, icon: record.icon,
                                            color: record.color), sortOrder: record.sortOrder)
        apply(record)
    }

    func apply(_ record: TrackerRecord) {
        id = record.id
        name = record.name
        kindRaw = record.kind.rawValue
        unit = record.unit
        unitPlural = record.unitPlural
        defaultAmount = record.defaultAmount
        scaleMin = record.scaleMin
        scaleMax = record.scaleMax
        icon = record.icon
        colorName = record.color
        sortOrder = record.sortOrder
        archived = record.archived
        createdAt = record.createdAt
        reminderMinutes = record.reminderMinutes
    }
}

extension CheckInSchedule {
    convenience init(record: ScheduleRecord) {
        self.init(name: record.name, time: ClockTime(hour: record.hour, minute: record.minute),
                  trackerIDs: record.trackerIDs)
        apply(record)
    }

    func apply(_ record: ScheduleRecord) {
        id = record.id
        name = record.name
        hour = record.hour
        minute = record.minute
        weekdayMask = record.weekdayMask
        trackerIDs = record.trackerIDs
        enabled = record.enabled
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }
}

extension LogEntry {
    convenience init(record: EntryRecord) {
        self.init(value: record.value, occurredAt: record.occurredAt, source: record.source, note: record.note)
        id = record.id
        loggedAt = record.loggedAt
        timeZoneID = record.timeZoneID
        scheduledFor = record.scheduledFor
        sessionID = record.sessionID
    }
}

extension CheckInSession {
    convenience init(record: SessionRecord) {
        self.init(scheduleID: record.scheduleID, scheduledFor: record.scheduledFor)
        id = record.id
        openedAt = record.openedAt
        completedAt = record.completedAt
        status = record.status
        questionCount = record.questionCount
        answeredCount = record.answeredCount
    }
}

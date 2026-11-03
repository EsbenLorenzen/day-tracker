import Foundation

/// Full-fidelity copy of all data (D17). Written as `backup.json` in every export.
public struct Backup: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var trackers: [TrackerRecord]
    public var entries: [EntryRecord]
    public var schedules: [ScheduleRecord]
    public var sessions: [SessionRecord]

    public init(
        version: Int = Backup.currentVersion,
        exportedAt: Date,
        trackers: [TrackerRecord],
        entries: [EntryRecord],
        schedules: [ScheduleRecord],
        sessions: [SessionRecord]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.trackers = trackers
        self.entries = entries
        self.schedules = schedules
        self.sessions = sessions
    }
}

public struct TrackerRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var kind: TrackerKind
    public var unit: String?
    public var unitPlural: String?
    public var defaultAmount: Double
    public var scaleMin: Int?
    public var scaleMax: Int?
    public var icon: String
    public var color: String
    public var sortOrder: Int
    public var archived: Bool
    public var createdAt: Date
    public var reminderMinutes: [Int]

    public init(
        id: UUID, name: String, kind: TrackerKind, unit: String? = nil, unitPlural: String? = nil,
        defaultAmount: Double = 1, scaleMin: Int? = nil, scaleMax: Int? = nil, icon: String, color: String,
        sortOrder: Int, archived: Bool = false, createdAt: Date, reminderMinutes: [Int] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.unit = unit
        self.unitPlural = unitPlural
        self.defaultAmount = defaultAmount
        self.scaleMin = scaleMin
        self.scaleMax = scaleMax
        self.icon = icon
        self.color = color
        self.sortOrder = sortOrder
        self.archived = archived
        self.createdAt = createdAt
        self.reminderMinutes = reminderMinutes
    }
}

public struct EntryRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var trackerID: UUID?
    public var value: Double
    public var occurredAt: Date
    public var loggedAt: Date
    public var timeZoneID: String
    public var source: EntrySource
    public var note: String?
    public var scheduledFor: Date?
    public var sessionID: UUID?

    public init(
        id: UUID, trackerID: UUID?, value: Double, occurredAt: Date, loggedAt: Date, timeZoneID: String,
        source: EntrySource, note: String? = nil, scheduledFor: Date? = nil, sessionID: UUID? = nil
    ) {
        self.id = id
        self.trackerID = trackerID
        self.value = value
        self.occurredAt = occurredAt
        self.loggedAt = loggedAt
        self.timeZoneID = timeZoneID
        self.source = source
        self.note = note
        self.scheduledFor = scheduledFor
        self.sessionID = sessionID
    }
}

public struct ScheduleRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var hour: Int
    public var minute: Int
    public var weekdayMask: Int
    public var trackerIDs: [UUID]
    public var enabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID, name: String, hour: Int, minute: Int, weekdayMask: Int, trackerIDs: [UUID],
        enabled: Bool, createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.hour = hour
        self.minute = minute
        self.weekdayMask = weekdayMask
        self.trackerIDs = trackerIDs
        self.enabled = enabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct SessionRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var scheduleID: UUID
    public var scheduledFor: Date
    public var openedAt: Date?
    public var completedAt: Date?
    public var status: CheckInStatus
    public var questionCount: Int
    public var answeredCount: Int

    public init(
        id: UUID, scheduleID: UUID, scheduledFor: Date, openedAt: Date? = nil, completedAt: Date? = nil,
        status: CheckInStatus, questionCount: Int, answeredCount: Int
    ) {
        self.id = id
        self.scheduleID = scheduleID
        self.scheduledFor = scheduledFor
        self.openedAt = openedAt
        self.completedAt = completedAt
        self.status = status
        self.questionCount = questionCount
        self.answeredCount = answeredCount
    }
}

public enum BackupError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case missingBackupFile
    case invalidArchive
    case compressedArchive
}

extension Backup {
    /// Reads a backup from `backup.json` or from an export `.zip` made by the app.
    public static func decode(_ data: Data) throws -> Backup {
        let json: Data
        if data.starts(with: StoredZip.localHeaderSignatureBytes) {
            let files = try StoredZip.extract(data)
            guard let file = files.first(where: { $0.key.hasSuffix(Exporter.backupFileName) }) else {
                throw BackupError.missingBackupFile
            }
            json = file.value
        } else {
            json = data
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: json)
        guard backup.version <= Backup.currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }
        return backup
    }

    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

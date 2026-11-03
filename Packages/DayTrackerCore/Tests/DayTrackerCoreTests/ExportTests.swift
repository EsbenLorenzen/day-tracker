import Foundation
import Testing
@testable import DayTrackerCore

/// Sample data matching `Fixtures/*.csv`. The same fixtures are loaded by analysis/tests in Python,
/// so this pins the export format on both sides (D17).
enum SampleBackup {
    static func id(_ suffix: Int) -> UUID {
        let hex = String(suffix)
        let padded = String(repeating: "0", count: 12 - hex.count) + hex
        return UUID(uuidString: "00000000-0000-0000-0000-\(padded)")!
    }

    static func make() throws -> Backup {
        let cal = try calendar("Europe/Copenhagen")
        let zone = "Europe/Copenhagen"
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) throws -> Date {
            try date(cal, 2026, 11, day, hour, minute).addingTimeInterval(TimeInterval(second))
        }
        let created = try at(1, 12)

        let trackers = [
            TrackerRecord(id: id(1), name: "Water", kind: .counter, unit: "glass", unitPlural: "glasses",
                          icon: "drop.fill", color: "blue", sortOrder: 0, createdAt: created),
            TrackerRecord(id: id(2), name: "Coffee", kind: .counter, unit: "cup", unitPlural: "cups",
                          icon: "cup.and.saucer.fill", color: "brown", sortOrder: 1, createdAt: created),
            TrackerRecord(id: id(3), name: "Vitamin D", kind: .dose, icon: "pills.fill", color: "red",
                          sortOrder: 2, createdAt: created, reminderMinutes: [480]),
            TrackerRecord(id: id(4), name: "Energy", kind: .scale, scaleMin: 1, scaleMax: 10,
                          icon: "bolt.fill", color: "orange", sortOrder: 3, createdAt: created),
        ]

        func entry(_ n: Int, _ tracker: Int, _ value: Double, _ when: Date, _ source: EntrySource = .manual,
                   note: String? = nil, scheduledFor: Date? = nil, session: Int? = nil) -> EntryRecord {
            EntryRecord(id: id(n), trackerID: id(tracker), value: value, occurredAt: when, loggedAt: when,
                        timeZoneID: zone, source: source, note: note, scheduledFor: scheduledFor,
                        sessionID: session.map { id($0) })
        }

        // Deliberately not in time order: the export sorts.
        let entries = [
            entry(101, 1, 1, try at(2, 9)),
            entry(102, 1, 1, try at(2, 13, 30)),
            entry(103, 2, 1, try at(2, 15)),
            entry(104, 3, 1, try at(2, 8, 5), .notificationAction, scheduledFor: try at(2, 8)),
            entry(105, 4, 6, try at(2, 21), .checkIn, session: 201),
            entry(106, 2, 1, try at(3, 1, 30)),  // before 04:00, so day = Nov 2
            entry(107, 4, 7, try at(3, 9), note: "Slept well, finally"),
            entry(108, 3, 0, try at(3, 9, 10), scheduledFor: try at(3, 8)),
        ]

        let schedules = [
            ScheduleRecord(id: id(301), name: "Evening", hour: 21, minute: 0, weekdayMask: Weekdays.everyDay.rawValue,
                           trackerIDs: [id(4)], enabled: true, createdAt: created, updatedAt: created),
            ScheduleRecord(id: id(302), name: "Morning", hour: 9, minute: 0, weekdayMask: Weekdays.workdays.rawValue,
                           trackerIDs: [id(4)], enabled: true, createdAt: created, updatedAt: created),
        ]

        let sessions = [
            SessionRecord(id: id(202), scheduleID: id(302), scheduledFor: try at(3, 9),
                          status: .missed, questionCount: 1, answeredCount: 0),
            SessionRecord(id: id(201), scheduleID: id(301), scheduledFor: try at(2, 21),
                          openedAt: try at(2, 21, 0, 10), completedAt: try at(2, 21, 0, 20),
                          status: .answered, questionCount: 1, answeredCount: 1),
        ]

        return Backup(exportedAt: try at(3, 22), trackers: trackers, entries: entries,
                      schedules: schedules, sessions: sessions)
    }
}

private func fixture(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
    return try String(contentsOf: url, encoding: .utf8)
}

@Suite struct ExportTests {
    let boundary = DayBoundary(startHour: 4)

    @Test func entriesMatchFixture() throws {
        let expected = try fixture("entries.csv")
        let csv = Exporter.entriesCSV(try SampleBackup.make(), dayBoundary: boundary)
        #expect(csv == expected)
    }

    @Test func trackersMatchFixture() throws {
        let expected = try fixture("trackers.csv")
        let csv = Exporter.trackersCSV(try SampleBackup.make())
        #expect(csv == expected)
    }

    @Test func checkInsMatchFixture() throws {
        let zone = try #require(TimeZone(identifier: "Europe/Copenhagen"))
        let expected = try fixture("checkins.csv")
        let csv = Exporter.checkInsCSV(try SampleBackup.make(), timeZone: zone, dayBoundary: boundary)
        #expect(csv == expected)
    }

    @Test func csvQuoting() {
        #expect(CSV.field("plain") == "plain")
        #expect(CSV.field("a, b") == "\"a, b\"")
        #expect(CSV.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSV.field("two\nlines") == "\"two\nlines\"")
    }

    @Test func backupJSONRoundTrip() throws {
        let backup = try SampleBackup.make()
        let decoded = try Backup.decode(backup.encodedJSON())
        #expect(decoded == backup)
    }

    @Test func archiveRoundTrip() throws {
        let backup = try SampleBackup.make()
        let zone = try #require(TimeZone(identifier: "Europe/Copenhagen"))
        let zip = try Exporter.archive(backup, timeZone: zone, dayBoundary: boundary)
        let files = try StoredZip.extract(zip)
        let expectedEntries = try fixture("entries.csv")
        let entries = files["entries.csv"].map { String(decoding: $0, as: UTF8.self) }
        let decoded = try Backup.decode(zip)
        #expect(Set(files.keys) == ["entries.csv", "trackers.csv", "checkins.csv", "backup.json", "README.txt"])
        #expect(entries == expectedEntries)
        #expect(decoded == backup)
    }

    @Test func newerBackupVersionIsRejected() throws {
        var backup = try SampleBackup.make()
        backup.version = Backup.currentVersion + 1
        let json = try backup.encodedJSON()
        #expect(throws: BackupError.unsupportedVersion(Backup.currentVersion + 1)) {
            try Backup.decode(json)
        }
    }
}

@Suite struct StoredZipTests {
    @Test func crc32KnownValue() {
        #expect(StoredZip.crc32(Data("123456789".utf8)) == 0xCBF4_3926)
    }

    @Test func layout() {
        let zip = StoredZip.archive([("a.txt", Data("hello".utf8))], modified: Date(timeIntervalSince1970: 1_800_000_000))
        // local header 30 + name 5 + data 5, central header 46 + name 5, end record 22
        #expect(zip.count == 30 + 5 + 5 + 46 + 5 + 22)
        #expect(Array(zip.prefix(4)) == [0x50, 0x4B, 0x03, 0x04])
        #expect(Array(zip.suffix(22).prefix(4)) == [0x50, 0x4B, 0x05, 0x06])
    }

    @Test func emptyDataIsInvalid() {
        #expect(throws: BackupError.invalidArchive) {
            try StoredZip.extract(Data())
        }
    }
}

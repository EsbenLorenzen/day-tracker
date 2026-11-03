import Foundation
import SwiftData
import DayTrackerCore

@MainActor
enum Seeder {
    private static let checkInsSeededKey = "seededDefaultCheckIns"

    static func seedIfNeeded(_ context: ModelContext) {
        seedTrackers(context)
        seedCheckIns(context)
    }

    /// Creates the default trackers on first launch.
    private static func seedTrackers(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Tracker>())) ?? 0
        guard count == 0 else { return }
        for (index, template) in DefaultTrackers.all.enumerated() {
            context.insert(Tracker(template: template, sortOrder: index))
        }
        try? context.save()
    }

    /// Creates the default check-ins once, also for installs from before Phase 2.
    /// A flag (not "no schedules exist") so deleting them all doesn't bring them back.
    private static func seedCheckIns(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: checkInsSeededKey) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<CheckInSchedule>())) ?? 0
        if existing == 0 {
            let trackers = (try? context.fetch(FetchDescriptor<Tracker>())) ?? []
            let questionIDs = DefaultCheckIns.questionNames.compactMap { name in
                trackers.first { $0.name == name && $0.kind == .scale }?.id
            }
            for template in DefaultCheckIns.all {
                context.insert(CheckInSchedule(name: template.name, time: template.time, trackerIDs: questionIDs))
            }
            try? context.save()
        }
        defaults.set(true, forKey: checkInsSeededKey)
    }
}

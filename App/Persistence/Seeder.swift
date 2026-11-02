import SwiftData
import DayTrackerCore

@MainActor
enum Seeder {
    /// Creates the default trackers on first launch.
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Tracker>())) ?? 0
        guard count == 0 else { return }
        for (index, template) in DefaultTrackers.all.enumerated() {
            context.insert(Tracker(template: template, sortOrder: index))
        }
        try? context.save()
    }
}

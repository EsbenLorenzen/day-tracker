import Foundation
import SwiftData
import DayTrackerCore

/// Something that can be logged (D07). Archived instead of deleted so history stays intact.
@Model
final class Tracker {
    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = TrackerKind.counter.rawValue
    var unit: String?
    var unitPlural: String?
    var defaultAmount: Double = 1
    var scaleMin: Int?
    var scaleMax: Int?
    var icon: String = "circle"
    var colorName: String = "blue"
    var sortOrder: Int = 0
    var archived: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \LogEntry.tracker)
    var entries: [LogEntry] = []

    init(template: TrackerTemplate, sortOrder: Int) {
        self.name = template.name
        self.kindRaw = template.kind.rawValue
        self.unit = template.unit
        self.unitPlural = template.unitPlural
        self.defaultAmount = template.defaultAmount
        self.scaleMin = template.scaleRange?.lowerBound
        self.scaleMax = template.scaleRange?.upperBound
        self.icon = template.icon
        self.colorName = template.color
        self.sortOrder = sortOrder
    }

    var kind: TrackerKind {
        TrackerKind(rawValue: kindRaw) ?? .counter
    }

    var scaleRange: ClosedRange<Int> {
        let lower = scaleMin ?? 1
        return lower...max(lower, scaleMax ?? 10)
    }

    /// Display text for one entry's value.
    func format(_ value: Double) -> String {
        switch kind {
        case .counter, .number:
            ValueFormat.amount(value, singular: unit, plural: unitPlural)
        case .dose:
            value >= 1 ? "Taken" : "Skipped"
        case .scale:
            "\(ValueFormat.number(value)) / \(scaleRange.upperBound)"
        case .note:
            "Note"
        }
    }
}

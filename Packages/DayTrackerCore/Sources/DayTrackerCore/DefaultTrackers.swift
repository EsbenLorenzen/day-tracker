/// Blueprint for a tracker; the app turns these into stored trackers.
public struct TrackerTemplate: Sendable, Equatable {
    public var name: String
    public var kind: TrackerKind
    public var unit: String?
    public var unitPlural: String?
    public var defaultAmount: Double
    public var scaleRange: ClosedRange<Int>?
    /// SF Symbol name.
    public var icon: String
    /// Color token, mapped to a SwiftUI color in the app.
    public var color: String

    public init(
        name: String,
        kind: TrackerKind,
        unit: String? = nil,
        unitPlural: String? = nil,
        defaultAmount: Double = 1,
        scaleRange: ClosedRange<Int>? = nil,
        icon: String,
        color: String
    ) {
        self.name = name
        self.kind = kind
        self.unit = unit
        self.unitPlural = unitPlural
        self.defaultAmount = defaultAmount
        self.scaleRange = scaleRange
        self.icon = icon
        self.color = color
    }
}

/// Trackers created on first launch, in display order.
public enum DefaultTrackers {
    public static let all: [TrackerTemplate] = [
        TrackerTemplate(name: "Water", kind: .counter, unit: "glass", unitPlural: "glasses",
                        icon: "drop.fill", color: "blue"),
        TrackerTemplate(name: "Coffee", kind: .counter, unit: "cup", unitPlural: "cups",
                        icon: "cup.and.saucer.fill", color: "brown"),
        TrackerTemplate(name: "Medicine", kind: .dose,
                        icon: "pills.fill", color: "red"),
        TrackerTemplate(name: "Mood", kind: .scale, scaleRange: 1...10,
                        icon: "face.smiling", color: "yellow"),
        TrackerTemplate(name: "Energy", kind: .scale, scaleRange: 1...10,
                        icon: "bolt.fill", color: "orange"),
        TrackerTemplate(name: "Focus", kind: .scale, scaleRange: 1...10,
                        icon: "scope", color: "purple"),
    ]
}

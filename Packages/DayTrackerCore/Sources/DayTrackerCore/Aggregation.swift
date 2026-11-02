import Foundation

/// The parts of an entry that aggregation needs.
public struct LoggedValue: Sendable, Equatable {
    public var value: Double
    public var occurredAt: Date

    public init(value: Double, occurredAt: Date) {
        self.value = value
        self.occurredAt = occurredAt
    }
}

/// A day's entries for one tracker, summarised according to its kind.
public enum DailyAggregate: Sendable, Equatable {
    case total(Double)
    case doses(taken: Int, skipped: Int)
    case scale(latest: Double?, average: Double?, count: Int)
    case notes(count: Int)
}

extension TrackerKind {
    public func aggregate(_ values: [LoggedValue]) -> DailyAggregate {
        switch self {
        case .counter, .number:
            return .total(values.reduce(0) { $0 + $1.value })
        case .dose:
            let taken = values.filter { $0.value >= 1 }.count
            return .doses(taken: taken, skipped: values.count - taken)
        case .scale:
            guard !values.isEmpty else { return .scale(latest: nil, average: nil, count: 0) }
            let latest = values.max { $0.occurredAt < $1.occurredAt }?.value
            let average = values.reduce(0) { $0 + $1.value } / Double(values.count)
            return .scale(latest: latest, average: average, count: values.count)
        case .note:
            return .notes(count: values.count)
        }
    }
}

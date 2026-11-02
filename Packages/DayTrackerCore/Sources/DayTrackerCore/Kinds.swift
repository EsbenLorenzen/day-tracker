/// What kind of value a tracker records (D07).
public enum TrackerKind: String, Codable, CaseIterable, Sendable {
    /// Tap +1 (water, coffee). Value = amount added.
    case counter
    /// Medicine taken/skipped (D11). Value 1 = taken, 0 = skipped.
    case dose
    /// Rating within a range, e.g. 1–10 (D12).
    case scale
    /// Free numeric value.
    case number
    /// Text only; value unused.
    case note
}

/// Where an entry came from. Stored for analysis.
public enum EntrySource: String, Codable, CaseIterable, Sendable {
    case manual
    case notificationAction
    case checkIn
    case widget
    case shortcut
}

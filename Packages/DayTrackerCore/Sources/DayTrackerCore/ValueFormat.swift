/// Plain-text formatting shared by the app and exports.
public enum ValueFormat {
    /// "3" for whole numbers, "1.5" otherwise.
    public static func number(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(value)
    }

    /// "1 glass", "3 glasses", or just "3" without a unit.
    public static func amount(_ value: Double, singular: String?, plural: String?) -> String {
        let number = number(value)
        guard let singular else { return number }
        return "\(number) \(value == 1 ? singular : (plural ?? singular))"
    }
}

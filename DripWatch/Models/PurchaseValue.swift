import Foundation

/// Locale-aware purchase input kept separate from the view so edit/save round trips are testable.
enum PurchaseValue {
    /// Mirrors Postgres `numeric(12,2)` so an accepted local price can always sync.
    static let maximumPriceCents = 999_999_999_999

    static func editingText(_ value: Double, maxFractionDigits: Int, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }

    static func positiveNumber(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var normalized = trimmed
        if let grouping = locale.groupingSeparator, !grouping.isEmpty {
            normalized = normalized.replacingOccurrences(of: grouping, with: "")
        }
        if let decimal = locale.decimalSeparator, decimal != "." {
            normalized = normalized.replacingOccurrences(of: decimal, with: ".")
        }
        normalized = normalized.replacingOccurrences(of: "\u{00a0}", with: "")
            .replacingOccurrences(of: "\u{202f}", with: "")

        guard let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return value
    }

    static func priceCents(_ text: String, locale: Locale = .current) -> Int? {
        guard let value = positiveNumber(text, locale: locale) else { return nil }
        let rawCents = value * 100
        let rounded = rawCents.rounded()
        guard abs(rawCents - rounded) < 0.000_001,
              rounded <= Double(maximumPriceCents) else { return nil }
        return Int(rounded)
    }
}

import SwiftUI
import UIKit

/// A monochrome, shadcn-inspired system: a near-neutral zinc base, hairline borders, and a
/// single disciplined **red** accent. Color enters only through bag photos, the accent, and the
/// tinted "next brew" plan card. Numeric params are set in a monospaced face so they read like
/// instrument data. Text stays on semantic colors (Dynamic Type / contrast); containers use the
/// explicit neutral tokens below so light and dark both look intentional.
enum Theme {
    /// Page canvas — off-white / near-black (zinc-50 / zinc-950).
    static let canvas = Color.adaptive(
        light: UIColor(white: 0.98, alpha: 1),
        dark: UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1)
    )

    /// Raised card surface — white / zinc-900.
    static let surface = Color.adaptive(
        light: UIColor(white: 1.0, alpha: 1),
        dark: UIColor(red: 0.094, green: 0.094, blue: 0.106, alpha: 1)
    )

    /// Hairline border / subtle fills — zinc-200 / zinc-800. (Named `crema` historically; now
    /// the neutral line color used for borders, dividers, chip fills, and empty dots.)
    static let crema = Color.adaptive(
        light: UIColor(red: 0.894, green: 0.894, blue: 0.906, alpha: 1),
        dark: UIColor(red: 0.153, green: 0.153, blue: 0.165, alpha: 1)
    )

    /// The one accent — red-600 / red-500.
    static let accent = Color.adaptive(
        light: UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 1),
        dark: UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)
    )

    /// Positive taste — emerald. Paired with a "+" symbol so it never relies on color alone.
    static let sage = Color.adaptive(
        light: UIColor(red: 0.020, green: 0.588, blue: 0.412, alpha: 1),
        dark: UIColor(red: 0.204, green: 0.827, blue: 0.600, alpha: 1)
    )

    /// Negative taste — rose (distinct from the primary accent). Paired with a "−" symbol.
    static let clay = Color.adaptive(
        light: UIColor(red: 0.882, green: 0.114, blue: 0.282, alpha: 1),
        dark: UIColor(red: 0.984, green: 0.443, blue: 0.522, alpha: 1)
    )

    /// Standard spacing increments (HIG §1: 8 / 16 / 24).
    enum Space { static let s: CGFloat = 8, m: CGFloat = 16, l: CGFloat = 24 }

    /// Corner radius for cards / controls (shadcn rounded-xl ≈ 14).
    static let radius: CGFloat = 14

    /// A hairline-bordered card with a whisper of shadow.
    struct Card: ViewModifier {
        var padding: CGFloat = Theme.Space.m
        func body(content: Content) -> some View {
            content
                .padding(padding)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .strokeBorder(Theme.crema, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
        }
    }
}

extension View {
    func dripCard(padding: CGFloat = Theme.Space.m) -> some View { modifier(Theme.Card(padding: padding)) }

    /// Guarantees at least a 44×44pt tappable area without changing the visual size (HIG §1).
    func hitTarget(_ size: CGFloat = 44) -> some View {
        frame(minWidth: size, minHeight: size).contentShape(Rectangle())
    }

    /// Editorial uppercase label styling — tracked, muted, small.
    func overline() -> some View {
        font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    /// When a numeric-keyboard text field within this view begins editing, select its whole
    /// contents so typing *replaces* the value instead of appending — no backspacing to clear a
    /// seeded number. Attach once per screen; it applies to every numeric field inside. Prose
    /// fields (default keyboard) are left alone.
    func selectAllWhenNumericFocused() -> some View {
        onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
            guard let field = note.object as? UITextField else { return }
            switch field.keyboardType {
            case .numberPad, .decimalPad, .numbersAndPunctuation:
                DispatchQueue.main.async { field.selectAll(nil) }
            default:
                break
            }
        }
    }
}

extension Font {
    /// Monospaced numeric/param face — the "instrument data" look.
    static func param(_ style: Font.TextStyle = .body, weight: Font.Weight = .medium) -> Font {
        .system(style, design: .monospaced).weight(weight)
    }
}

extension Color {
    /// A color that resolves per appearance — the HIG-endorsed way to support Dark Mode.
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// A small pill for taste chips and metadata. Pairs a symbol with the tint so meaning is
/// never carried by color alone (HIG §6).
struct Chip: View {
    let text: String
    var symbol: String? = nil
    var tint: Color = .secondary
    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).imageScale(.small) }
            Text(text)
        }
        .font(.footnote.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12))
        .foregroundStyle(tint)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 0.5))
    }
}

/// Meaningful, subtle haptics (HIG §8).
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

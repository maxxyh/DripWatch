import SwiftUI

/// A horizontal, draggable ruler for a stepless grinder — scrub the strip so the value under the
/// fixed centre indicator changes, snapping to `step` (0.5). It mirrors dialling a worm-drive
/// grinder like the DF54, where the setting is a continuous number rather than counted clicks.
///
/// The bound value is always a clean multiple of `step`; a decimal field beside it (in the
/// picker) covers precise entry. Meaning never rests on color alone — the value is also shown as
/// text and exposed to VoiceOver as an adjustable control.
struct GrindRuler: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    let step: Double = 0.5

    /// Screen distance between two adjacent 0.5 ticks. Larger = coarser, easier scrubbing.
    private let pxPerStep: CGFloat = 16
    private var pxPerUnit: CGFloat { pxPerStep / CGFloat(step) }

    @State private var dragStartValue: Double?

    var body: some View {
        Canvas { ctx, size in
            let centre = size.width / 2
            let v = value
            let halfUnits = Double(centre / pxPerUnit)
            let lo = max(range.lowerBound, v - halfUnits - step)
            let hi = min(range.upperBound, v + halfUnits + step)

            var t = (lo / step).rounded(.down) * step
            while t <= hi + 0.0001 {
                let x = centre + CGFloat(t - v) * pxPerUnit
                let isMajor = t.truncatingRemainder(dividingBy: 1) == 0
                let tickHeight: CGFloat = isMajor ? 18 : 10
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height - tickHeight))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: .color(tickColor), lineWidth: isMajor ? 1.5 : 1)

                if isMajor {
                    var label = ctx.resolve(Text("\(Int(t))").font(.system(.caption2, design: .monospaced)))
                    label.shading = .color(Color(.secondaryLabel))
                    ctx.draw(label, at: CGPoint(x: x, y: size.height - tickHeight - 8))
                }
                t += step
            }
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(Theme.crema.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .center) {
            // Fixed centre indicator: the value that "reads" on the dial.
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 2)
                .padding(.vertical, 6)
        }
        .overlay(alignment: .top) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 9))
                .foregroundStyle(Theme.accent)
                .offset(y: -2)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    let base = dragStartValue ?? value
                    if dragStartValue == nil { dragStartValue = value }
                    let raw = base - Double(g.translation.width) / Double(pxPerUnit)
                    let snapped = (raw / step).rounded() * step
                    let clamped = min(max(snapped, range.lowerBound), range.upperBound)
                    if clamped != value { value = clamped; Haptics.select() }
                }
                .onEnded { _ in dragStartValue = nil }
        )
        .accessibilityElement()
        .accessibilityLabel("Grind setting")
        .accessibilityValue(GrindSetting(grinderName: "", major: value).majorText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            default: break
            }
            Haptics.select()
        }
    }

    private var tickColor: Color { Color(.label).opacity(0.35) }
}

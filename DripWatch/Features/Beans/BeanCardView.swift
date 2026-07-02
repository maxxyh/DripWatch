import SwiftUI

/// The character card: the bag photo as the hero visual, over a roaster-style fact block.
/// Two layouts share this file — a compact `.shelf` tile for the grid and a `.full` header
/// for the detail screen.
struct BeanCardView: View {
    let bean: Bean
    enum Style { case shelf, full }
    var style: Style = .shelf
    /// When set (detail header), tapping the bag photo opens the full-screen preview.
    var onTapPhoto: (() -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var notesExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo
            info
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.crema, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: Hero photo (or a warm placeholder when there's no bag shot yet)

    @ViewBuilder private var photo: some View {
        // Only attach a tap gesture when there's a preview handler (detail). On the shelf there
        // is none, so the tap falls through to the enclosing NavigationLink and opens the bean.
        if onTapPhoto != nil, bean.primaryPhotoData != nil {
            photoContent.onTapGesture { Haptics.tap(); onTapPhoto?() }
        } else {
            photoContent
        }
    }

    private var photoContent: some View {
        ZStack {
            if let data = bean.primaryPhotoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                // Neutral placeholder — color only ever comes from a real bag photo.
                Theme.crema.opacity(0.6)
                Image(systemName: "drop.fill")
                    .font(.system(size: style == .full ? 46 : 30))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .accessibilityHidden(true)
            }
        }
        .frame(height: style == .full ? 220 : 128)
        .frame(maxWidth: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .overlay(alignment: .topLeading) {
            // A hint that there's more than one bag surface to swipe through.
            if bean.photoDatas.count > 1 {
                Chip(text: "\(bean.photoDatas.count)", symbol: "photo.on.rectangle", tint: .white)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(10)
            }
        }
        .overlay(alignment: .topTrailing) {
            // "Brews together" — the relationship counter, not a rank.
            // `.white` is intentional here (not a Theme token): the badge sits on an arbitrary
            // bag photo over ultraThinMaterial, so it must stay legible in either appearance.
            if bean.brewCount > 0 {
                Chip(text: "\(bean.brewCount)×", symbol: "cup.and.saucer.fill", tint: .white)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(10)
            }
        }
    }

    // MARK: Fact block (roaster-card style)

    private var info: some View {
        VStack(alignment: .leading, spacing: style == .full ? 12 : 6) {
            Text(bean.name.isEmpty ? "Untitled bean" : bean.name)
                .font(style == .full ? .title2.bold() : .headline)
                .foregroundStyle(Color(.label))
                .lineLimit(style == .full ? 2 : 1)

            if let roaster = bean.roasterName, !roaster.isEmpty {
                Text(roaster.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
            }

            if style == .shelf {
                if let sub = shelfSubtitle {
                    Text(sub)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                // Roaster's tasting notes on the shelf — the enticement to pick this bag.
                roasterNoteChips(limit: 3)
            } else {
                factRows
                if !bean.roasterNoteList.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Roaster notes").overline()
                        roasterNoteChips()
                    }
                }
                if !bean.myFlavorTags.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your tags").overline()
                        FlowChips(items: bean.myFlavorTags)
                    }
                }
            }
        }
        .padding(style == .full ? Theme.Space.m : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shelfSubtitle: String? {
        [bean.process, bean.country].compactMap { $0?.isEmpty == false ? $0 : nil }.first
    }

    /// The roaster's tasting notes as accent chips (a highlight, distinct from origin facts and
    /// the user's own tags). `limit` caps the shelf tile to N chips with a tappable "+N" that
    /// expands the card to show the rest (and a "less" to collapse).
    @ViewBuilder private func roasterNoteChips(limit: Int? = nil) -> some View {
        let notes = bean.roasterNoteList
        if !notes.isEmpty {
            let collapsed = limit != nil && !notesExpanded
            let shown = collapsed ? Array(notes.prefix(limit!)) : notes
            let extra = notes.count - shown.count
            WrapLayout(spacing: 6, lineSpacing: 6) {
                ForEach(shown, id: \.self) {
                    Chip(text: shelfText($0), symbol: "sparkles", tint: Theme.accent)
                }
                if extra > 0 {
                    Button { Haptics.tap(); withAnimation { notesExpanded = true } } label: {
                        Chip(text: "+\(extra)", tint: .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show \(extra) more tasting notes")
                } else if notesExpanded, let limit, notes.count > limit {
                    Button { Haptics.tap(); withAnimation { notesExpanded = false } } label: {
                        Chip(text: "less", symbol: "chevron.up", tint: .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show fewer tasting notes")
                }
            }
        }
    }

    /// Keep shelf chips from overflowing the narrow tile — truncate an over-long note.
    private func shelfText(_ note: String) -> String {
        guard style == .shelf, note.count > 18 else { return note }
        return note.prefix(17).trimmingCharacters(in: .whitespaces) + "…"
    }

    @ViewBuilder private var factRows: some View {
        VStack(alignment: .leading, spacing: 5) {
            fact("REGION", [bean.region, bean.country].compactMap { $0 }.joined(separator: ", "))
            fact("FARM", bean.farm)
            fact("VARIETY", bean.varietal)
            fact("PROCESS", bean.process)
            fact("ROAST", bean.roastLevel)
            if let d = bean.roastDate { fact("ROASTED", roastedText(d)) }
        }
    }

    /// e.g. "12 Jun · 20 days ago" — the age is what actually matters day-to-day.
    private func roastedText(_ date: Date) -> String {
        let base = date.formatted(date: .abbreviated, time: .omitted)
        guard let days = bean.daysSinceRoast else { return base }
        let age: String
        switch days {
        case ..<0: age = "future date"
        case 0: age = "today"
        case 1: age = "1 day ago"
        default: age = "\(days) days ago"
        }
        return "\(base) · \(age)"
    }

    @ViewBuilder private func fact(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            let labelText = Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            let valueText = Text(value).font(.subheadline).foregroundStyle(Color(.label))
            Group {
                if typeSize.isAccessibilitySize {
                    // At large accessibility sizes, stack so nothing truncates.
                    VStack(alignment: .leading, spacing: 1) { labelText; valueText }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        labelText.frame(width: 78, alignment: .leading)
                        valueText
                        Spacer(minLength: 0)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label): \(value)")
        }
    }

    private var accessibilitySummary: String {
        var s = bean.name.isEmpty ? "Untitled bean" : bean.name
        if let r = bean.roasterName, !r.isEmpty { s += ", roasted by \(r)" }
        s += ", \(bean.togetherLabel.lowercased())"
        return s
    }
}

/// A simple wrapping row of flavor-tag chips.
struct FlowChips: View {
    let items: [String]
    var tint: Color = Theme.crema
    var body: some View {
        WrapLayout(spacing: 6, lineSpacing: 6) {
            ForEach(items, id: \.self) { Chip(text: $0, tint: tint) }
        }
    }
}

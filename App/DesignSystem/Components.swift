import SwiftUI

// MARK: - Containers

extension View {
    func kPanel(_ padding: CGFloat = 14) -> some View {
        self.padding(padding)
            .background(Theme.surface)
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }

    func screenBackground() -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.bg.ignoresSafeArea())
    }

    /// La marge gauche/droite standard d'un écran. À appliquer sur le contenu
    /// racine de chaque écran pour garder un même retrait sur tous les iPhone.
    func screenPadding() -> some View {
        self.padding(.horizontal, Space.screenH)
    }
}

// MARK: - Layout

/// Lays its children left-to-right and wraps to a new line when the current row is
/// full, so a set of tags fills a few fixed lines instead of scrolling sideways.
struct FlowLayout: Layout {
    var spacing: CGFloat = 7
    var lineSpacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(maxWidth: maxWidth, subviews: subviews)
        let width = maxWidth.isFinite ? maxWidth : (rows.map(\.width).max() ?? 0)
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var y = bounds.minY
        for row in rows(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let projected = row.items.isEmpty ? size.width : row.width + spacing + size.width
            if projected > maxWidth && !row.items.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.items.append(i)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}

// MARK: - Buttons

struct PixelButton: View {
    enum Style { case filled, ghost }
    let title: String
    var style: Style = .filled
    var fullWidth: Bool = true
    let action: () -> Void
    @Environment(\.accent) private var accent
    /// `.disabled(...)` bloque le tap sans rien changer à l'apparence : sans ce
    /// grisé, un bouton inactif reste pleinement coloré et le joueur tape dessus
    /// en boucle sans comprendre pourquoi rien ne se passe.
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(KFont.mono(13, bold: true))
                .tracking(2)
                .foregroundStyle(style == .filled ? Theme.accentInk : Theme.text)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.vertical, 15)
                .padding(.horizontal, 18)
                .background(style == .filled ? accent : Color.clear)
                .overlay(Rectangle().stroke(style == .filled ? accent : Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
    }
}

// MARK: - Tags / labels

struct KTag: View {
    let title: String
    var selected: Bool = false
    @Environment(\.accent) private var accent

    var body: some View {
        Text(title.uppercased())
            .font(KFont.mono(9))
            .tracking(1)
            .foregroundStyle(selected ? accent : Theme.muted)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .overlay(Rectangle().stroke(selected ? accent : Theme.border, lineWidth: 1))
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(KFont.mono(9))
            .tracking(1.5)
            .foregroundStyle(Theme.muted)
    }
}

// MARK: - Coins / score / XP

struct CoinLabel: View {
    let amount: Int
    var color: Color?
    /// Taille du chiffre ; la pastille suit proportionnellement.
    var size: CGFloat = 14
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: size * 0.36) {
            Circle().strokeBorder(color ?? accent, lineWidth: 1.5)
                .frame(width: size * 0.64, height: size * 0.64)
            Text("\(amount)")
                .font(KFont.mono(size, bold: true))
                .foregroundStyle(color ?? accent)
        }
    }
}

struct ScoreText: View {
    let value: Int
    var size: CGFloat = 50
    @Environment(\.accent) private var accent
    var body: some View {
        Text("\(value)")
            .font(KFont.pixel(size))
            .foregroundStyle(accent)
    }
}

struct XPBar: View {
    let fraction: Double
    @Environment(\.accent) private var accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(hex: "#0c0c0c"))
                Rectangle()
                    .fill(accent)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 7)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - Bars used in screens

struct TopBar: View {
    let coins: Int
    let level: Int
    var onGear: (() -> Void)?
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: 12) {
            CoinLabel(amount: coins)
            Spacer()
            Text("LVL \(level)")
                .font(KFont.mono(10)).tracking(1)
                .foregroundStyle(Theme.muted)
                .padding(.vertical, 4).padding(.horizontal, 8)
                .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
            if let onGear {
                Button(action: onGear) {
                    Image(systemName: "gearshape").font(.system(size: 15)).foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct BackHeader: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Button { dismiss() } label: {
                Text("◀ RETOUR")
                    .font(KFont.mono(11)).foregroundStyle(Theme.text)
                    .padding(.vertical, 8).padding(.horizontal, 11)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(title.uppercased()).font(KFont.mono(13, bold: true)).tracking(1)
                .foregroundStyle(Theme.text)
            Spacer()
            Color.clear.frame(width: 84, height: 1)
        }
    }
}

// MARK: - Navigation button

/// A `PixelButton`-styled `NavigationLink`. Use this for forward navigation
/// (push) instead of an action button.
struct NavButton: View {
    let title: String
    var style: PixelButton.Style = .filled
    let route: Route
    @Environment(\.accent) private var accent

    var body: some View {
        NavigationLink(value: route) {
            Text(title.uppercased())
                .font(KFont.mono(13, bold: true))
                .tracking(2)
                .foregroundStyle(style == .filled ? Theme.accentInk : Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .padding(.horizontal, 18)
                .background(style == .filled ? accent : Color.clear)
                .overlay(Rectangle().stroke(style == .filled ? accent : Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Logo

/// The lightning-bolt mark, traced from the SVG path `M13 10V3L4 14h7v7l9-11h-7z`
/// on a 24x24 grid. Scales to fill its frame.
struct BoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Normalised points (x/24, y/24) of the SVG path.
        let pts: [(CGFloat, CGFloat)] = [
            (13, 10), (13, 3), (4, 14), (11, 14), (11, 21), (20, 10), (13, 10),
        ]
        var path = Path()
        for (i, p) in pts.enumerated() {
            let point = CGPoint(x: rect.minX + p.0 / 24 * rect.width,
                                y: rect.minY + p.1 / 24 * rect.height)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The bolt mark on its own (used for compact spots and the app icon source).
struct BoltMark: View {
    var size: CGFloat = 34
    @Environment(\.accent) private var accent
    var body: some View {
        BoltShape()
            .fill(accent)
            .frame(width: size, height: size)
    }
}

struct KwizzLogo: View {
    var size: CGFloat = 34
    /// When false, only the bolt mark is shown (no wordmark).
    var showsWordmark: Bool = true
    @Environment(\.accent) private var accent
    var body: some View {
        HStack(spacing: size * 0.18) {
            BoltMark(size: size)
            if showsWordmark {
                HStack(spacing: 0) {
                    Text("K").font(KFont.pixel(size)).foregroundStyle(Theme.text)
                    Text("W").font(KFont.pixel(size)).foregroundStyle(accent)
                    Text("IZZ").font(KFont.pixel(size)).foregroundStyle(Theme.text)
                }
            }
        }
    }
}

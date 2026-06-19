import SwiftUI

extension Color {
    /// Creates a colour from a "#rrggbb" or "#rrggbbaa" hex string.
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b, a: Double
        switch s.count {
        case 8:
            r = Double((value >> 24) & 0xff) / 255
            g = Double((value >> 16) & 0xff) / 255
            b = Double((value >> 8) & 0xff) / 255
            a = Double(value & 0xff) / 255
        default:
            r = Double((value >> 16) & 0xff) / 255
            g = Double((value >> 8) & 0xff) / 255
            b = Double(value & 0xff) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// The arcade-minimal palette: a near-black, almost monochrome base with a single
/// accent colour used sparingly. See mockups/prototype.html.
enum Theme {
    static let bg = Color(hex: "#161616")
    static let bg2 = Color(hex: "#101010")
    static let surface = Color(hex: "#1b1b1b")
    static let surface2 = Color(hex: "#202020")
    static let border = Color(hex: "#3d3d3d")
    static let text = Color(hex: "#f0f0f0")
    static let muted = Color(hex: "#6b6b6b")
    static let faint = Color(hex: "#3a3a3a")
    static let bad = Color(hex: "#ff5066")

    /// Dark "ink" used for text on top of a bright accent fill.
    static let accentInk = Color(hex: "#0c0c0c")

    enum Accent: String, CaseIterable, Identifiable {
        case vert, ambre, cyan, mono
        var id: String { rawValue }
        var title: String {
            switch self {
            case .vert: "Vert"
            case .ambre: "Ambre"
            case .cyan: "Cyan"
            case .mono: "Mono"
            }
        }
        var hex: String {
            switch self {
            case .vert: "#00ff88"
            case .ambre: "#ffb000"
            case .cyan: "#38d6ff"
            case .mono: "#f0f0f0"
            }
        }
        var color: Color { Color(hex: hex) }
    }
}

enum Space {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    /// Marge gauche/droite standard d'un écran, pour que le contenu et les
    /// cadres ne touchent jamais le bord, sur tous les iPhone.
    static let screenH: CGFloat = 20
    static let radius: CGFloat = 0   // sharp corners, arcade-terminal feel
}

/// Font helpers. Press Start 2P for the logo and big arcade scores; Space Mono for
/// chrome (labels, tags, numbers); the system font for body copy. Custom fonts
/// fall back to the system font automatically if not bundled.
enum KFont {
    static func pixel(_ size: CGFloat) -> Font { .custom("Press Start 2P", size: size) }
    static func mono(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "SpaceMono-Bold" : "SpaceMono-Regular", size: size)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Accent through the environment

private struct AccentColorKey: EnvironmentKey {
    static let defaultValue = Theme.Accent.vert.color
}

extension EnvironmentValues {
    var accent: Color {
        get { self[AccentColorKey.self] }
        set { self[AccentColorKey.self] = newValue }
    }
}

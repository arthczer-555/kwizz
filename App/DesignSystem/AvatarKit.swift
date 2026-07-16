import SwiftUI

// MARK: - Avatar model
//
// The avatar is composed by layers on a shared 160 x 166 canvas so every piece
// registers perfectly. Back to front: fond -> dos (cape/ailes, behind the body)
// -> base body (the level look) -> haut -> cou (collier/écharpe) -> cheveux -> face
// -> lunettes -> tete -> main (objet tenu, devant), with cadre drawn as an outer border.
//
// The "base body" is NOT a slot: it is driven by the player's LEVEL. It evolves
// from level 1 ("Américain moyen", dazed) to level 20 ("Émilien", glowing genius).
// Everything here is procedural (drawn in code) so the app is fully clothed at
// zero cost; polished pixel-art sprites can replace these later, layer by layer.

/// A resolved avatar: the level (drives the base body) plus the equipped cosmetics.
struct AvatarLook {
    var level: Int
    var items: [AvatarSlot: AvatarItem]

    init(level: Int, items: [AvatarSlot: AvatarItem] = [:]) {
        self.level = level
        self.items = items
    }
}

enum EyeStyle { case dazed, plain, focused, sharp, glow }
enum MouthStyle { case agape, flat, smile, smirk, line }

/// The face + glow parameters for a given level. Expression changes in bands; the
/// aura grows continuously, so every level reads as a small step up.
struct LevelTraits {
    var eyes: EyeStyle
    var mouth: MouthStyle
    var aura: Double      // 0...1, glow intensity behind the head
}

func levelTraits(_ level: Int) -> LevelTraits {
    let l = min(max(level, 1), 20)
    let aura = Double(l - 1) / 19.0
    let eyes: EyeStyle
    let mouth: MouthStyle
    switch l {
    case 1...3:   eyes = .dazed;   mouth = .agape
    case 4...7:   eyes = .plain;   mouth = .flat
    case 8...12:  eyes = .focused; mouth = .smile
    case 13...17: eyes = .sharp;   mouth = .smirk
    default:      eyes = .glow;    mouth = .line
    }
    return LevelTraits(eyes: eyes, mouth: mouth, aura: aura)
}

// MARK: - Canvas geometry (reference 160 x 166, scale 1)

private enum AV {
    static let w: CGFloat = 160
    static let h: CGFloat = 166
    static let cx: CGFloat = 80
    static let headC = CGPoint(x: 80, y: 46)
    static let headD: CGFloat = 42
    static let torsoCY: CGFloat = 109
    static let eyeY: CGFloat = 44
    static let eyeLX: CGFloat = 72
    static let eyeRX: CGFloat = 88
    static let mouthY: CGFloat = 55
}

private enum Pal {
    static let cloth1 = Color(hex: "#2c2c2c")
    static let cloth2 = Color(hex: "#242424")
    static let cloth3 = Color(hex: "#141414")
    static let hair = Color(hex: "#2f2f2f")
    static let hat = Color(hex: "#c2c7cd")
    static let hatShade = Color(hex: "#8d949c")
    static let gold = Color(hex: "#ffb000")
    static let green = Color(hex: "#00ff88")
    static let epic = Color(hex: "#c084fc")
}

// MARK: - The composited avatar view

struct AvatarLayeredView: View {
    var look: AvatarLook
    var scale: CGFloat = 1
    var showShadow: Bool = true
    var ring: Color? = nil
    @Environment(\.accent) private var accent

    var body: some View {
        let t = levelTraits(look.level)
        ZStack {
            background
            if showShadow { groundShadow }
            auraGlow(t)
            backAccessory
            bodyBase(t)
            clothing
            neckwear
            hair
            face(t)
            glasses
            headgear
            heldItem
            frameOverlay
        }
        .frame(width: AV.w, height: AV.h)
        .clipped()
        .scaleEffect(scale)
        .frame(width: AV.w * scale, height: AV.h * scale)
    }

    private func item(_ slot: AvatarSlot) -> String? { look.items[slot]?.id }

    // MARK: Base body + face

    private var bodyStroke: Color {
        let t = levelTraits(look.level)
        if let ring { return ring }
        return t.aura > 0.6 ? accent.opacity(0.85) : Theme.faint
    }

    private func bodyBase(_ t: LevelTraits) -> some View {
        let torso = UnevenRoundedRectangle(
            topLeadingRadius: 26, bottomLeadingRadius: 12,
            bottomTrailingRadius: 12, topTrailingRadius: 26
        )
        let stroke = bodyStroke
        return ZStack {
            torso.fill(Theme.surface2)
                .overlay(torso.stroke(stroke, lineWidth: 1))
                .frame(width: 66, height: 74)
                .position(x: AV.cx, y: AV.torsoCY)
            Circle().fill(Theme.surface2)
                .overlay(Circle().stroke(stroke, lineWidth: 1))
                .frame(width: AV.headD, height: AV.headD)
                .position(AV.headC)
        }
    }

    private func auraGlow(_ t: LevelTraits) -> some View {
        ZStack {
            Circle().fill(accent)
                .frame(width: 64, height: 64)
                .position(AV.headC)
                .blur(radius: 20)
                .opacity(t.aura * 0.45)
            if t.aura > 0.85 {
                Circle().stroke(accent.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 58, height: 58)
                    .position(AV.headC)
            }
        }
    }

    private var groundShadow: some View {
        Ellipse()
            .fill(RadialGradient(colors: [.black.opacity(0.65), .clear],
                                 center: .center, startRadius: 0, endRadius: 52))
            .frame(width: 104, height: 20)
            .position(x: AV.cx, y: 152)
    }

    private func face(_ t: LevelTraits) -> some View {
        ZStack { eyes(t.eyes); mouth(t.mouth) }
    }

    @ViewBuilder private func eyes(_ s: EyeStyle) -> some View {
        let lx = AV.eyeLX, rx = AV.eyeRX, y = AV.eyeY
        switch s {
        case .dazed:
            ZStack {
                Circle().fill(Theme.text).frame(width: 6, height: 6).position(x: lx - 1, y: y)
                Circle().fill(Theme.text).frame(width: 3, height: 3).position(x: rx + 1, y: y + 1)
            }
        case .plain:
            ZStack {
                Circle().fill(Theme.text).frame(width: 4, height: 4).position(x: lx, y: y)
                Circle().fill(Theme.text).frame(width: 4, height: 4).position(x: rx, y: y)
            }
        case .focused:
            ZStack {
                Capsule().fill(Theme.text).frame(width: 4, height: 7).position(x: lx, y: y)
                Capsule().fill(Theme.text).frame(width: 4, height: 7).position(x: rx, y: y)
            }
        case .sharp:
            ZStack {
                Rectangle().fill(Theme.text).frame(width: 10, height: 2.5)
                    .rotationEffect(.degrees(16)).position(x: lx, y: y)
                Rectangle().fill(Theme.text).frame(width: 10, height: 2.5)
                    .rotationEffect(.degrees(-16)).position(x: rx, y: y)
            }
        case .glow:
            ZStack {
                Circle().fill(accent).frame(width: 5, height: 5).position(x: lx, y: y)
                Circle().fill(accent).frame(width: 5, height: 5).position(x: rx, y: y)
                Circle().fill(accent).frame(width: 5, height: 5).position(x: lx, y: y).blur(radius: 4).opacity(0.9)
                Circle().fill(accent).frame(width: 5, height: 5).position(x: rx, y: y).blur(radius: 4).opacity(0.9)
            }
        }
    }

    @ViewBuilder private func mouth(_ s: MouthStyle) -> some View {
        let mx = AV.cx, my = AV.mouthY
        switch s {
        case .agape:
            Ellipse().fill(Color(hex: "#0c0c0c"))
                .overlay(Ellipse().stroke(Theme.text.opacity(0.5), lineWidth: 1))
                .frame(width: 8, height: 9).position(x: mx, y: my)
        case .flat:
            Capsule().fill(Theme.text).frame(width: 12, height: 2).position(x: mx, y: my)
        case .smile:
            SmileShape().stroke(Theme.text, lineWidth: 2)
                .frame(width: 16, height: 7).position(x: mx, y: my - 1)
        case .smirk:
            Capsule().fill(Theme.text).frame(width: 12, height: 2)
                .rotationEffect(.degrees(-12)).position(x: mx, y: my)
        case .line:
            Capsule().fill(Theme.text).frame(width: 14, height: 2).position(x: mx, y: my)
        }
    }

    // MARK: Fond (background)

    @ViewBuilder private var background: some View {
        switch item(.fond) {
        case "fond.uni":
            Rectangle().fill(Theme.surface)
        case "fond.degrade":
            LinearGradient(colors: [Color(hex: "#243b55"), Color(hex: "#141e30")],
                           startPoint: .top, endPoint: .bottom)
        case "fond.grille":
            ZStack {
                Rectangle().fill(Color(hex: "#121212"))
                GridShape().stroke(accent.opacity(0.25), lineWidth: 1)
            }
        case "fond.etoiles":
            ZStack {
                LinearGradient(colors: [Color(hex: "#0b1026"), Color(hex: "#05060f")],
                               startPoint: .top, endPoint: .bottom)
                ForEach(0..<22) { i in
                    Circle().fill(Color.white.opacity(0.8))
                        .frame(width: CGFloat(i % 3 == 0 ? 2.5 : 1.5))
                        .position(x: CGFloat((i * 37) % 160), y: CGFloat((i * 53) % 166))
                }
            }
        case "fond.galaxie":
            ZStack {
                Rectangle().fill(Color(hex: "#05030d"))
                RadialGradient(colors: [Pal.epic.opacity(0.7), Color(hex: "#38d6ff").opacity(0.25), .clear],
                               center: .center, startRadius: 4, endRadius: 90)
                SpiralShape().stroke(Color.white.opacity(0.35), lineWidth: 1.2)
            }
        case "fond.trounoir":
            ZStack {
                Rectangle().fill(Color.black)
                Circle().stroke(Pal.gold.opacity(0.9), lineWidth: 6)
                    .frame(width: 70, height: 70).blur(radius: 3).position(AV.headC)
                Circle().fill(Color.black).frame(width: 56, height: 56).position(AV.headC)
                RadialGradient(colors: [.clear, .black], center: .center, startRadius: 28, endRadius: 110)
            }
        case "fond.crt":
            ZStack {
                Rectangle().fill(Color(hex: "#0d0d0d"))
                Scanlines().stroke(Color.white.opacity(0.05), lineWidth: 1)
                RadialGradient(colors: [.clear, .black.opacity(0.6)],
                               center: .center, startRadius: 30, endRadius: 115)
            }
        case "fond.synthwave":
            ZStack {
                LinearGradient(colors: [Color(hex: "#1a0f2e"), Color(hex: "#0d0d12")],
                               startPoint: .top, endPoint: .bottom)
                SynthGrid().stroke(Pal.epic.opacity(0.45), lineWidth: 1)
            }
        case "fond.damier":
            ZStack {
                Rectangle().fill(Color(hex: "#e8e8e8"))
                CheckerShape().fill(Color(hex: "#1a1a1a"))
            }
        case "fond.neon":
            ZStack {
                Rectangle().fill(Color(hex: "#0a0a14"))
                ForEach(0..<6) { i in
                    let cols: [Color] = [Pal.epic, Color(hex: "#38d6ff"), Theme.bad]
                    Rectangle().fill(cols[i % 3].opacity(0.7)).frame(width: 3)
                        .position(x: CGFloat(14 + i * 27), y: AV.h / 2)
                        .shadow(color: cols[i % 3], radius: 4)
                }
            }
        case "fond.aurore":
            ZStack {
                LinearGradient(colors: [Color(hex: "#05060f"), Color(hex: "#0b1026")],
                               startPoint: .top, endPoint: .bottom)
                AuroraShape().fill(LinearGradient(
                    colors: [Pal.green.opacity(0.45), Color(hex: "#38d6ff").opacity(0.3), .clear],
                    startPoint: .top, endPoint: .bottom))
                    .blur(radius: 4)
                ForEach(0..<14) { i in
                    Circle().fill(Color.white.opacity(0.7)).frame(width: 1.5)
                        .position(x: CGFloat((i * 41) % 160), y: CGFloat((i * 29) % 70))
                }
            }
        case "fond.lave":
            ZStack {
                Rectangle().fill(Color(hex: "#1a0500"))
                RadialGradient(colors: [Color(hex: "#ff3b00").opacity(0.6), .clear],
                               center: .bottom, startRadius: 4, endRadius: 110)
                ForEach(0..<5) { i in
                    Rectangle().fill(Color(hex: "#ff6a00")).frame(width: 2, height: CGFloat(20 + i * 8))
                        .position(x: CGFloat(20 + i * 30), y: AV.h - CGFloat(20 + i * 6))
                        .shadow(color: Color(hex: "#ff3b00"), radius: 3)
                }
            }
        default:
            Color.clear
        }
    }

    // MARK: Haut (clothing over torso)

    @ViewBuilder private var clothing: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 24, bottomLeadingRadius: 12,
            bottomTrailingRadius: 12, topTrailingRadius: 24
        )
        switch item(.haut) {
        case "haut.tshirt":
            shape.fill(Color(hex: "#e8e8e8")).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
        case "haut.marin":
            ZStack {
                shape.fill(Color(hex: "#f0f0f0")).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                ForEach(0..<5) { i in
                    Rectangle().fill(Color(hex: "#1f3a8a")).frame(width: 56, height: 4)
                        .position(x: AV.cx, y: 86 + CGFloat(i) * 11)
                }
            }
            .mask(shape.frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1))
        case "haut.hawaii":
            ZStack {
                shape.fill(Color(hex: "#0f9b8e")).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                // floral print: leaf + hibiscus
                ForEach(0..<6) { i in
                    let fx = AV.cx - 18 + CGFloat(i % 3) * 18
                    let fy = 100 + CGFloat(i / 3) * 26
                    Ellipse().fill(Color(hex: "#0c7d6f")).frame(width: 12, height: 6)
                        .rotationEffect(.degrees(-30)).position(x: fx + 6, y: fy + 4)
                    Circle().fill(Color(hex: "#ff9f43")).frame(width: 9, height: 9).position(x: fx, y: fy)
                    Circle().fill(Color(hex: "#ffd23f")).frame(width: 3.5, height: 3.5).position(x: fx, y: fy)
                }
                // button placket
                ForEach(0..<4) { i in
                    Circle().fill(Color.white.opacity(0.85)).frame(width: 3, height: 3)
                        .position(x: AV.cx, y: 92 + CGFloat(i) * 13)
                }
                // open camp collar
                CampCollarShape().fill(Color(hex: "#0c7d6f")).frame(width: 38, height: 14).position(x: AV.cx, y: 82)
            }
            .mask(shape.frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1))
        case "haut.pull":
            ZStack {
                shape.fill(Pal.cloth1).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                Rectangle().fill(Theme.muted.opacity(0.6)).frame(width: 18, height: 2).position(x: AV.cx, y: 80)
            }
        case "haut.veste":
            ZStack {
                shape.fill(Pal.cloth2).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                Rectangle().fill(Theme.muted.opacity(0.7)).frame(width: 2, height: 56).position(x: AV.cx, y: 112)
                Rectangle().fill(Theme.faint).frame(width: 16, height: 2).rotationEffect(.degrees(28)).position(x: 70, y: 82)
                Rectangle().fill(Theme.faint).frame(width: 16, height: 2).rotationEffect(.degrees(-28)).position(x: 90, y: 82)
            }
        case "haut.costume":
            ZStack {
                shape.fill(Color(hex: "#232a36")).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                // white shirt in the V opening
                VNeckShape().fill(Color(hex: "#f2f3f5")).frame(width: 22, height: 30).position(x: AV.cx, y: 92)
                // jacket lapels
                LapelShape().fill(Color(hex: "#2c3543")).frame(width: 42, height: 34).position(x: AV.cx, y: 92)
                LapelShape().stroke(Color.black.opacity(0.3), lineWidth: 1).frame(width: 42, height: 34).position(x: AV.cx, y: 92)
                // tie
                TieShape().fill(accent).frame(width: 9, height: 28).position(x: AV.cx, y: 104)
                // buttons
                Circle().fill(Color.black.opacity(0.4)).frame(width: 3, height: 3).position(x: AV.cx, y: 128)
                Circle().fill(Color.black.opacity(0.4)).frame(width: 3, height: 3).position(x: AV.cx, y: 138)
            }
            .mask(shape.frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1))
        case "haut.bomber":
            ZStack {
                shape.fill(Color(hex: "#3a2f4a")).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                // ribbed collar
                Rectangle().fill(accent).frame(width: 62, height: 8).position(x: AV.cx, y: 78)
                ForEach(0..<10) { i in
                    Rectangle().fill(Color.black.opacity(0.15)).frame(width: 1, height: 8).position(x: 52 + CGFloat(i) * 6, y: 78)
                }
                // ribbed hem
                Rectangle().fill(accent).frame(width: 62, height: 7).position(x: AV.cx, y: 141)
                ForEach(0..<10) { i in
                    Rectangle().fill(Color.black.opacity(0.15)).frame(width: 1, height: 7).position(x: 52 + CGFloat(i) * 6, y: 141)
                }
                // zipper + pull
                Rectangle().fill(Color(hex: "#c8ccd0")).frame(width: 2, height: 58).position(x: AV.cx, y: 111)
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#e8ecf0")).frame(width: 4, height: 6).position(x: AV.cx, y: 90)
                // chest patch
                RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.9)).frame(width: 11, height: 7).position(x: 63, y: 100)
            }
            .mask(shape.frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1))
        case "haut.smoking":
            ZStack {
                shape.fill(Color(hex: "#0e0e13")).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                // white shirt front
                VNeckShape().fill(Color.white).frame(width: 20, height: 34).position(x: AV.cx, y: 94)
                // satin lapels
                LapelShape().fill(LinearGradient(colors: [Color(hex: "#2b2b34"), Color(hex: "#111116")],
                                                 startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 36).position(x: AV.cx, y: 94)
                // shirt studs
                ForEach(0..<3) { i in
                    Circle().fill(Color(hex: "#151515")).frame(width: 2.5, height: 2.5).position(x: AV.cx, y: 100 + CGFloat(i) * 8)
                }
                // white wing collar behind the bow tie (so it reads on the black jacket)
                RoundedRectangle(cornerRadius: 2).fill(Color.white).frame(width: 24, height: 8).position(x: AV.cx, y: 83)
                // black bow tie
                BowTieShape().fill(Color(hex: "#141414")).frame(width: 20, height: 11).position(x: AV.cx, y: 83)
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#2c2c2c")).frame(width: 4, height: 6).position(x: AV.cx, y: 83)
            }
            .mask(shape.frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1))
        case "haut.armure":
            ZStack {
                shape.fill(LinearGradient(colors: [Color(hex: "#c4ccd4"), Color(hex: "#828b95")],
                                          startPoint: .top, endPoint: .bottom))
                    .frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                // shoulder pauldrons
                Circle().fill(LinearGradient(colors: [Color(hex: "#d6dce2"), Color(hex: "#79828c")],
                                             startPoint: .top, endPoint: .bottom))
                    .frame(width: 26, height: 22).position(x: 52, y: 84)
                Circle().fill(LinearGradient(colors: [Color(hex: "#d6dce2"), Color(hex: "#79828c")],
                                             startPoint: .top, endPoint: .bottom))
                    .frame(width: 26, height: 22).position(x: 108, y: 84)
                // pectoral seams
                Rectangle().fill(Color(hex: "#5a626b")).frame(width: 2, height: 16).rotationEffect(.degrees(35)).position(x: 72, y: 98)
                Rectangle().fill(Color(hex: "#5a626b")).frame(width: 2, height: 16).rotationEffect(.degrees(-35)).position(x: 88, y: 98)
                // central ridge
                Rectangle().fill(Color.white.opacity(0.45)).frame(width: 2, height: 40).position(x: AV.cx, y: 118)
                // gold crest
                StarMark().fill(Pal.gold).frame(width: 14, height: 14).position(x: AV.cx, y: 106)
                // waist plate + rivets
                Rectangle().fill(Color(hex: "#6c727b")).frame(width: 62, height: 6).position(x: AV.cx, y: 134)
                ForEach(0..<2) { i in
                    Circle().fill(Color(hex: "#5a626b")).frame(width: 3, height: 3).position(x: 60 + CGFloat(i) * 40, y: 128)
                }
            }
            .mask(shape.frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1))
        case "haut.hoodie":
            ZStack {
                shape.fill(Color(hex: "#5a5a5a")).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                // hood draping at the neck
                RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#4a4a4a")).frame(width: 46, height: 18).position(x: AV.cx, y: 80)
                RoundedRectangle(cornerRadius: 9).fill(Color(hex: "#3d3d3d")).frame(width: 30, height: 12).position(x: AV.cx, y: 82)
                // drawstrings with aglets
                Rectangle().fill(Color(hex: "#d8d8d8")).frame(width: 2, height: 16).position(x: AV.cx - 5, y: 93)
                Rectangle().fill(Color(hex: "#d8d8d8")).frame(width: 2, height: 16).position(x: AV.cx + 5, y: 93)
                Circle().fill(Color(hex: "#d8d8d8")).frame(width: 4, height: 4).position(x: AV.cx - 5, y: 101)
                Circle().fill(Color(hex: "#d8d8d8")).frame(width: 4, height: 4).position(x: AV.cx + 5, y: 101)
                // kangaroo pocket
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#525252")).frame(width: 36, height: 18).position(x: AV.cx, y: 124)
                RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.3), lineWidth: 1.5).frame(width: 36, height: 18).position(x: AV.cx, y: 124)
            }
            .mask(shape.frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1))
        case "haut.maillot":
            ZStack {
                shape.fill(Color.white).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                ForEach(0..<3) { i in
                    Rectangle().fill(Color(hex: "#c8102e")).frame(width: 10, height: 70)
                        .position(x: AV.cx - 18 + CGFloat(i) * 18, y: AV.torsoCY + 1)
                }
                Rectangle().fill(Color(hex: "#1565c0")).frame(width: 62, height: 5).position(x: AV.cx, y: 78)
            }
            .mask(shape.frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1))
        case "haut.kimono":
            ZStack {
                shape.fill(Color(hex: "#ededed")).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                // white collar crossing into a V (folds shown by a soft grey)
                KimonoCollarShape().fill(Color(hex: "#dcdcdc")).frame(width: 46, height: 42).position(x: AV.cx, y: 97)
                KimonoCollarShape().stroke(Color.black.opacity(0.18), lineWidth: 1).frame(width: 46, height: 42).position(x: AV.cx, y: 97)
                // black obi belt
                Rectangle().fill(Color(hex: "#111318")).frame(width: 62, height: 13).position(x: AV.cx, y: 122)
                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 62, height: 1).position(x: AV.cx, y: 117)
                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 62, height: 1).position(x: AV.cx, y: 127)
                // obi knot
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#1b1e26")).frame(width: 14, height: 11).position(x: AV.cx, y: 122)
            }
            .mask(shape.frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1))
        case "haut.combinaison":
            ZStack {
                shape.fill(Color(hex: "#3f4b5c")).frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1)
                // open collar
                CampCollarShape().fill(Color(hex: "#4a586b")).frame(width: 40, height: 16).position(x: AV.cx, y: 84)
                // center zipper + pull
                Rectangle().fill(Color(hex: "#c9cdd3")).frame(width: 2, height: 42).position(x: AV.cx, y: 108)
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#e6e9ec")).frame(width: 4, height: 6).position(x: AV.cx, y: 92)
                // chest pockets
                RoundedRectangle(cornerRadius: 2).stroke(Color.black.opacity(0.3), lineWidth: 1.2).frame(width: 14, height: 12).position(x: 66, y: 100)
                RoundedRectangle(cornerRadius: 2).stroke(Color.black.opacity(0.3), lineWidth: 1.2).frame(width: 14, height: 12).position(x: 94, y: 100)
                // waist belt + buckle
                Rectangle().fill(Color(hex: "#2c3542")).frame(width: 62, height: 8).position(x: AV.cx, y: 124)
                RoundedRectangle(cornerRadius: 1).fill(accent).frame(width: 8, height: 8).position(x: AV.cx, y: 124)
            }
            .mask(shape.frame(width: 62, height: 70).position(x: AV.cx, y: AV.torsoCY + 1))
        default:
            EmptyView()
        }
    }

    // MARK: Cheveux (hair)

    @ViewBuilder private var hair: some View {
        switch item(.cheveux) {
        case "cheveux.couettes":
            ZStack {
                Capsule().fill(Pal.hair).frame(width: 46, height: 18).position(x: AV.cx, y: 24)
                Circle().fill(Pal.hair).frame(width: 16, height: 16).position(x: AV.cx - 26, y: 34)
                Circle().fill(Pal.hair).frame(width: 16, height: 16).position(x: AV.cx + 26, y: 34)
            }
        case "cheveux.banane":
            BananaShape().fill(Pal.hair)
                .overlay(BananaShape().stroke(Theme.faint, lineWidth: 1))
                .frame(width: 48, height: 26).position(x: AV.cx, y: 20)
        case "cheveux.afro":
            Ellipse().fill(Pal.hair)
                .overlay(Ellipse().stroke(Theme.faint, lineWidth: 1))
                .frame(width: 54, height: 34).position(x: AV.cx, y: 26)
        case "cheveux.tresses":
            ZStack {
                Capsule().fill(Pal.hair).frame(width: 46, height: 18).position(x: AV.cx, y: 24)
                BraidShape().fill(LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .blue, .purple],
                    startPoint: .top, endPoint: .bottom))
                    .frame(width: 8, height: 40).position(x: AV.cx - 24, y: 52)
                BraidShape().fill(LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .blue, .purple],
                    startPoint: .top, endPoint: .bottom))
                    .frame(width: 8, height: 40).position(x: AV.cx + 24, y: 52)
            }
        case "cheveux.mulet":
            ZStack {
                Ellipse().fill(Pal.hair).frame(width: 50, height: 22).position(x: AV.cx, y: 22)
                MulletShape().fill(Pal.hair).frame(width: 54, height: 40).position(x: AV.cx, y: 50)
            }
        case "cheveux.mohawk":
            MohawkShape().fill(accent)
                .frame(width: 18, height: 30).position(x: AV.cx, y: 20)
                .shadow(color: accent.opacity(0.6), radius: 3)
        case "cheveux.flammes":
            ZStack {
                FlameShape().fill(LinearGradient(
                    colors: [Color(hex: "#ff3b00"), Color(hex: "#ffb000"), Color(hex: "#ffe600")],
                    startPoint: .bottom, endPoint: .top))
                    .frame(width: 50, height: 40).position(x: AV.cx, y: 18)
                    .shadow(color: Color(hex: "#ff6a00").opacity(0.7), radius: 5)
            }
        case "cheveux.hologramme":
            Ellipse().fill(LinearGradient(
                colors: [Pal.epic.opacity(0.55), Color(hex: "#38d6ff").opacity(0.55)],
                startPoint: .leading, endPoint: .trailing))
                .overlay(Ellipse().stroke(Color(hex: "#38d6ff").opacity(0.8), lineWidth: 1))
                .frame(width: 54, height: 32).position(x: AV.cx, y: 24)
                .shadow(color: Color(hex: "#38d6ff").opacity(0.6), radius: 6)
        case "cheveux.carre":
            ZStack {
                Capsule().fill(Pal.hair).frame(width: 50, height: 20).position(x: AV.cx, y: 22)
                RoundedRectangle(cornerRadius: 4).fill(Pal.hair).frame(width: 8, height: 30).position(x: AV.cx - 22, y: 38)
                RoundedRectangle(cornerRadius: 4).fill(Pal.hair).frame(width: 8, height: 30).position(x: AV.cx + 22, y: 38)
            }
        case "cheveux.fleurs":
            ZStack {
                Capsule().fill(Pal.hair).frame(width: 46, height: 18).position(x: AV.cx, y: 24)
                ForEach(0..<5) { i in
                    let cols: [Color] = [Color(hex: "#ff7eb6"), Color(hex: "#ffd23f"), Pal.epic, Color(hex: "#ff7a59"), Color.white]
                    let fx = AV.cx + CGFloat(i - 2) * 12
                    let fy: CGFloat = 20 + CGFloat(abs(i - 2)) * 3
                    ZStack {
                        Circle().fill(cols[i]).frame(width: 11, height: 11).position(x: fx, y: fy)
                        Circle().fill(Color(hex: "#ffd23f")).frame(width: 4, height: 4).position(x: fx, y: fy)
                    }
                }
            }
        case "cheveux.dragon":
            ZStack {
                Ellipse().fill(Pal.hair).frame(width: 48, height: 20).position(x: AV.cx, y: 24)
                Circle().fill(Pal.hair).overlay(Circle().stroke(Theme.faint, lineWidth: 1))
                    .frame(width: 22, height: 22).position(x: AV.cx, y: 11)
                Capsule().fill(Pal.gold).frame(width: 3, height: 22)
                    .rotationEffect(.degrees(28)).position(x: AV.cx, y: 11)
                Capsule().fill(Pal.gold).frame(width: 3, height: 22)
                    .rotationEffect(.degrees(-28)).position(x: AV.cx, y: 11)
            }
        case "cheveux.galaxie":
            ZStack {
                Ellipse().fill(LinearGradient(
                    colors: [Pal.epic, Color(hex: "#38d6ff"), Color(hex: "#1a0f2e")],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 54, height: 32).position(x: AV.cx, y: 24)
                    .shadow(color: Pal.epic.opacity(0.6), radius: 5)
                ForEach(0..<7) { i in
                    Circle().fill(Color.white.opacity(0.9)).frame(width: i % 2 == 0 ? 2.5 : 1.5)
                        .position(x: AV.cx - 24 + CGFloat(i) * 8, y: 18 + CGFloat((i * 7) % 14))
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: Lunettes (glasses over the eyes)

    @ViewBuilder private var glasses: some View {
        let lx = AV.eyeLX, rx = AV.eyeRX, y = AV.eyeY
        switch item(.lunettes) {
        case "lunettes.carrees":
            ZStack {
                RoundedRectangle(cornerRadius: 2).stroke(Theme.text, lineWidth: 1.5).frame(width: 13, height: 11).position(x: lx, y: y)
                RoundedRectangle(cornerRadius: 2).stroke(Theme.text, lineWidth: 1.5).frame(width: 13, height: 11).position(x: rx, y: y)
                Rectangle().fill(Theme.text).frame(width: 6, height: 1.5).position(x: AV.cx, y: y)
            }
        case "lunettes.soleil":
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#0c0c0c")).frame(width: 14, height: 11).position(x: lx, y: y)
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#0c0c0c")).frame(width: 14, height: 11).position(x: rx, y: y)
                Rectangle().fill(Color(hex: "#0c0c0c")).frame(width: 6, height: 2).position(x: AV.cx, y: y)
            }
        case "lunettes.aviateur":
            ZStack {
                TeardropShape().fill(Color(hex: "#9fd9ff").opacity(0.85))
                    .overlay(TeardropShape().stroke(Pal.gold, lineWidth: 1.2))
                    .frame(width: 14, height: 12).position(x: lx, y: y + 1)
                TeardropShape().fill(Color(hex: "#9fd9ff").opacity(0.85))
                    .overlay(TeardropShape().stroke(Pal.gold, lineWidth: 1.2))
                    .frame(width: 14, height: 12).position(x: rx, y: y + 1)
                Rectangle().fill(Pal.gold).frame(width: 6, height: 1.5).position(x: AV.cx, y: y)
            }
        case "lunettes.monocle":
            ZStack {
                Circle().stroke(Pal.gold, lineWidth: 1.8).frame(width: 15, height: 15).position(x: rx, y: y)
                Circle().fill(Color.white.opacity(0.12)).frame(width: 13, height: 13).position(x: rx, y: y)
                Path { p in
                    p.move(to: CGPoint(x: rx, y: y + 8))
                    p.addLine(to: CGPoint(x: rx - 4, y: 70))
                }.stroke(Pal.gold, lineWidth: 1)
            }
        case "lunettes.cyber":
            VisorShape().fill(LinearGradient(
                colors: [Pal.epic, Color(hex: "#38d6ff")], startPoint: .leading, endPoint: .trailing))
                .overlay(VisorShape().stroke(Theme.text.opacity(0.6), lineWidth: 1))
                .frame(width: 44, height: 12).position(x: AV.cx, y: y)
                .shadow(color: Pal.epic.opacity(0.7), radius: 4)
        case "lunettes.lasers":
            ZStack {
                Rectangle().fill(Color(hex: "#111")).frame(width: 40, height: 10).position(x: AV.cx, y: y)
                Circle().fill(Theme.bad).frame(width: 8, height: 8).position(x: lx, y: y)
                Circle().fill(Theme.bad).frame(width: 8, height: 8).position(x: rx, y: y)
                Rectangle().fill(Theme.bad).frame(width: 70, height: 2).position(x: lx - 24, y: y)
                    .shadow(color: Theme.bad, radius: 4)
                Rectangle().fill(Theme.bad).frame(width: 70, height: 2).position(x: rx + 24, y: y)
                    .shadow(color: Theme.bad, radius: 4)
            }
        case "lunettes.rondes":
            ZStack {
                Circle().stroke(Theme.text, lineWidth: 1.5).frame(width: 13, height: 13).position(x: lx, y: y)
                Circle().stroke(Theme.text, lineWidth: 1.5).frame(width: 13, height: 13).position(x: rx, y: y)
                Rectangle().fill(Theme.text).frame(width: 6, height: 1.5).position(x: AV.cx, y: y)
            }
        case "lunettes.neon":
            ZStack {
                Circle().stroke(accent, lineWidth: 1.5).frame(width: 13, height: 13).position(x: lx, y: y)
                Circle().stroke(accent, lineWidth: 1.5).frame(width: 13, height: 13).position(x: rx, y: y)
                Rectangle().fill(accent).frame(width: 6, height: 1.5).position(x: AV.cx, y: y)
            }
            .shadow(color: accent, radius: 3)
        case "lunettes.masque":
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#0c0c0c"))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(accent, lineWidth: 1))
                .overlay(Rectangle().fill(accent.opacity(0.7)).frame(height: 1.5).padding(.horizontal, 4))
                .frame(width: 40, height: 13).position(x: AV.cx, y: y)
        case "lunettes.coeur":
            ZStack {
                HeartMark().fill(Color(hex: "#ff4d6d")).frame(width: 14, height: 12).position(x: lx, y: y)
                HeartMark().fill(Color(hex: "#ff4d6d")).frame(width: 14, height: 12).position(x: rx, y: y)
                Rectangle().fill(Color(hex: "#ff4d6d")).frame(width: 6, height: 1.5).position(x: AV.cx, y: y - 1)
            }
        case "lunettes.pixel":
            ZStack {
                Rectangle().fill(Color.black).frame(width: 16, height: 9).position(x: lx, y: y)
                Rectangle().fill(Color.black).frame(width: 16, height: 9).position(x: rx, y: y)
                Rectangle().fill(Color.black).frame(width: 6, height: 4).position(x: AV.cx, y: y)
                Rectangle().fill(Color.white.opacity(0.85)).frame(width: 4, height: 3).position(x: lx - 3, y: y - 1)
                Rectangle().fill(Color.white.opacity(0.85)).frame(width: 4, height: 3).position(x: rx - 3, y: y - 1)
            }
        case "lunettes.diamant":
            ZStack {
                Circle().stroke(Color(hex: "#dff6ff"), lineWidth: 1.5).frame(width: 13, height: 13).position(x: lx, y: y)
                Circle().stroke(Color(hex: "#dff6ff"), lineWidth: 1.5).frame(width: 13, height: 13).position(x: rx, y: y)
                Rectangle().fill(Color(hex: "#dff6ff")).frame(width: 6, height: 1.5).position(x: AV.cx, y: y)
                DiamondMark().fill(Color(hex: "#9fe8ff")).frame(width: 6, height: 6).position(x: lx - 7, y: y - 5)
                DiamondMark().fill(Color(hex: "#9fe8ff")).frame(width: 6, height: 6).position(x: rx + 7, y: y - 5)
            }
            .shadow(color: Color(hex: "#9fe8ff").opacity(0.6), radius: 2)
        default:
            EmptyView()
        }
    }

    // MARK: Tete (headgear over the top of the head)

    @ViewBuilder private var headgear: some View {
        switch item(.tete) {
        case "tete.bob":
            ZStack {
                Ellipse().fill(Pal.hat).frame(width: 50, height: 10).position(x: AV.cx, y: 32)
                RoundedRectangle(cornerRadius: 12).fill(Pal.hat).frame(width: 40, height: 22).position(x: AV.cx, y: 24)
                Rectangle().fill(Pal.hatShade).frame(width: 40, height: 3).position(x: AV.cx, y: 30)
            }
        case "tete.casquette":
            ZStack {
                CapShape().fill(Pal.hat).frame(width: 46, height: 22).position(x: AV.cx, y: 28)
                Ellipse().fill(Pal.hatShade).frame(width: 26, height: 7).position(x: AV.cx + 16, y: 33)
            }
        case "tete.bonnet":
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Pal.hat).frame(width: 46, height: 26).position(x: AV.cx, y: 25)
                Rectangle().fill(Pal.hatShade).frame(width: 46, height: 5).position(x: AV.cx, y: 35)
                Circle().fill(Pal.hat).frame(width: 9, height: 9).position(x: AV.cx, y: 10)
            }
        case "tete.beret":
            ZStack {
                Ellipse().fill(Pal.hat).frame(width: 46, height: 22)
                    .rotationEffect(.degrees(-10)).position(x: AV.cx, y: 24)
                Circle().fill(Pal.hatShade).frame(width: 6, height: 6).position(x: AV.cx, y: 13)
            }
        case "tete.hautdeforme":
            ZStack {
                Ellipse().fill(Pal.hat).frame(width: 50, height: 9).position(x: AV.cx, y: 27)
                Rectangle().fill(Pal.hat).frame(width: 32, height: 26).position(x: AV.cx, y: 14)
                Rectangle().fill(Theme.bad.opacity(0.7)).frame(width: 32, height: 4).position(x: AV.cx, y: 22)
            }
        case "tete.casque":
            ZStack {
                ArcBandShape().stroke(Pal.hat, lineWidth: 5)
                    .frame(width: 56, height: 40).position(x: AV.cx, y: 30)
                RoundedRectangle(cornerRadius: 4).fill(accent).frame(width: 11, height: 18).position(x: AV.cx - 27, y: 40)
                RoundedRectangle(cornerRadius: 4).fill(accent).frame(width: 11, height: 18).position(x: AV.cx + 27, y: 40)
            }
        case "tete.toque":
            ZStack {
                Capsule().fill(Color(hex: "#f4f4f4")).frame(width: 38, height: 14).position(x: AV.cx, y: 30)
                Circle().fill(Color(hex: "#f4f4f4")).frame(width: 18, height: 18).position(x: AV.cx - 9, y: 17)
                Circle().fill(Color(hex: "#f4f4f4")).frame(width: 22, height: 22).position(x: AV.cx + 8, y: 15)
                Circle().fill(Color(hex: "#ffffff")).frame(width: 16, height: 16).position(x: AV.cx, y: 12)
            }
        case "tete.aureole":
            ZStack {
                Ellipse().stroke(Pal.gold, lineWidth: 3).frame(width: 40, height: 12).position(x: AV.cx, y: 11)
                Ellipse().stroke(Pal.gold.opacity(0.6), lineWidth: 6).frame(width: 40, height: 12)
                    .blur(radius: 4).position(x: AV.cx, y: 11)
            }
        case "tete.couronne":
            CrownShape().fill(Pal.gold)
                .frame(width: 40, height: 20).position(x: AV.cx, y: 23)
                .shadow(color: Pal.gold.opacity(0.6), radius: 4)
        case "tete.serretete":
            ZStack {
                Capsule().fill(Color(hex: "#e23b8a")).frame(width: 46, height: 7).position(x: AV.cx, y: 28)
                Circle().fill(Color(hex: "#e23b8a")).frame(width: 11, height: 11).position(x: AV.cx + 20, y: 24)
                Circle().fill(Color(hex: "#ff7eb6")).frame(width: 4, height: 4).position(x: AV.cx + 20, y: 24)
            }
        case "tete.melon":
            ZStack {
                Ellipse().fill(Pal.hat).frame(width: 48, height: 9).position(x: AV.cx, y: 31)
                Capsule().fill(Pal.hat).frame(width: 34, height: 26).position(x: AV.cx, y: 20)
                Rectangle().fill(Pal.hatShade).frame(width: 34, height: 4).position(x: AV.cx, y: 29)
            }
        case "tete.cowboy":
            ZStack {
                Ellipse().fill(Color(hex: "#8a5a2b")).frame(width: 60, height: 14).position(x: AV.cx, y: 32)
                Capsule().fill(Color(hex: "#8a5a2b")).frame(width: 30, height: 26).position(x: AV.cx, y: 18)
                Rectangle().fill(Color(hex: "#3a2410")).frame(width: 30, height: 4).position(x: AV.cx, y: 28)
            }
        case "tete.viking":
            ZStack {
                Capsule().fill(LinearGradient(colors: [Color(hex: "#c8ccd0"), Color(hex: "#7c858f")],
                                              startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 30).position(x: AV.cx, y: 26)
                Rectangle().fill(Color(hex: "#5a626b")).frame(width: 44, height: 4).position(x: AV.cx, y: 30)
                HornShape().fill(Color(hex: "#f0e6d2"))
                    .frame(width: 18, height: 24).position(x: AV.cx - 26, y: 20)
                HornShape().fill(Color(hex: "#f0e6d2"))
                    .frame(width: 18, height: 24).scaleEffect(x: -1).position(x: AV.cx + 26, y: 20)
            }
        default:
            EmptyView()
        }
    }

    // MARK: Cadre (frame border)

    @ViewBuilder private var frameOverlay: some View {
        switch item(.cadre) {
        case "cadre.bois":
            Rectangle().stroke(Color(hex: "#7a4a24"), lineWidth: 4).padding(2)
        case "cadre.argent":
            ZStack {
                Rectangle().stroke(Color(hex: "#c8ccd0"), lineWidth: 2).padding(1)
                Rectangle().stroke(Color(hex: "#8a9098").opacity(0.6), lineWidth: 1).padding(4)
            }
        case "cadre.vert":
            Rectangle().stroke(Pal.green, lineWidth: 2).padding(1)
        case "cadre.flammes":
            Rectangle().stroke(LinearGradient(
                colors: [Color(hex: "#ff3b00"), Color(hex: "#ffb000")],
                startPoint: .top, endPoint: .bottom), lineWidth: 3).padding(1)
                .shadow(color: Color(hex: "#ff6a00").opacity(0.7), radius: 4)
        case "cadre.glace":
            Rectangle().stroke(LinearGradient(
                colors: [Color(hex: "#9fe8ff"), Color(hex: "#38d6ff")],
                startPoint: .top, endPoint: .bottom), lineWidth: 2.5).padding(1)
                .shadow(color: Color(hex: "#38d6ff").opacity(0.7), radius: 4)
        case "cadre.diamant":
            ZStack {
                Rectangle().stroke(Color(hex: "#dff6ff"), lineWidth: 2).padding(1)
                ForEach(0..<4) { i in
                    DiamondMark().fill(Color(hex: "#9fe8ff"))
                        .frame(width: 8, height: 8)
                        .position(x: i % 2 == 0 ? 6 : AV.w - 6, y: i < 2 ? 6 : AV.h - 6)
                }
            }.shadow(color: Color(hex: "#9fe8ff").opacity(0.6), radius: 3)
        case "cadre.arcenciel":
            Rectangle().stroke(AngularGradient(
                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                center: .center), lineWidth: 3).padding(1)
                .shadow(color: Pal.epic.opacity(0.6), radius: 4)
        case "cadre.or":
            ZStack {
                Rectangle().stroke(Pal.gold, lineWidth: 2).padding(1)
                Rectangle().stroke(Pal.gold.opacity(0.4), lineWidth: 1).padding(4)
            }
        case "cadre.pixel":
            Rectangle().stroke(accent, style: StrokeStyle(lineWidth: 4, dash: [6, 3])).padding(2)
        case "cadre.neon":
            Rectangle().stroke(accent, lineWidth: 2).padding(2)
                .shadow(color: accent, radius: 5)
        case "cadre.lauriers":
            ZStack {
                Rectangle().stroke(Pal.gold, lineWidth: 2).padding(1)
                ForEach(0..<8) { i in
                    let lx: CGFloat = i < 4 ? CGFloat(42 + i * 8) : AV.w - 42 - CGFloat((i - 4) * 8)
                    Ellipse().fill(Pal.gold.opacity(0.85)).frame(width: 9, height: 4)
                        .rotationEffect(.degrees(i < 4 ? 40 : -40))
                        .position(x: lx, y: AV.h - 8)
                }
            }
        case "cadre.foudre":
            Rectangle().stroke(LinearGradient(
                colors: [Color(hex: "#fff27a"), Color(hex: "#38d6ff")],
                startPoint: .top, endPoint: .bottom), lineWidth: 3).padding(1)
                .shadow(color: Color(hex: "#38d6ff").opacity(0.8), radius: 5)
        default:
            EmptyView()
        }
    }

    // MARK: Cou (necklace / scarf over the chest)

    @ViewBuilder private var neckwear: some View {
        switch item(.cou) {
        case "cou.foulard":
            ZStack {
                Capsule().fill(Color(hex: "#e23b3b")).frame(width: 30, height: 9).position(x: AV.cx, y: 72)
                TriangleDown().fill(Color(hex: "#e23b3b")).frame(width: 16, height: 14).position(x: AV.cx, y: 81)
            }
        case "cou.cravate":
            ZStack {
                Rectangle().fill(Color(hex: "#b8252e")).frame(width: 8, height: 6).position(x: AV.cx, y: 73)
                TieShape().fill(Color(hex: "#b8252e")).frame(width: 11, height: 28).position(x: AV.cx, y: 94)
            }
        case "cou.echarpe":
            ZStack {
                Capsule().fill(Color(hex: "#2e7d5b")).frame(width: 42, height: 14).position(x: AV.cx, y: 74)
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#2e7d5b")).frame(width: 12, height: 30).position(x: AV.cx - 9, y: 94)
                ForEach(0..<3) { i in
                    Rectangle().fill(Color.white.opacity(0.5)).frame(width: 12, height: 2).position(x: AV.cx - 9, y: 86 + CGFloat(i) * 7)
                }
            }
        case "cou.chaine":
            ChainShape().stroke(Pal.gold, lineWidth: 2.5)
                .frame(width: 40, height: 26).position(x: AV.cx, y: 80)
                .shadow(color: Pal.gold.opacity(0.5), radius: 2)
        case "cou.medaille":
            ZStack {
                ChainShape().stroke(Pal.gold, lineWidth: 2)
                    .frame(width: 40, height: 24).position(x: AV.cx, y: 78)
                Circle().fill(Pal.gold).overlay(Circle().stroke(Color(hex: "#a87800"), lineWidth: 1))
                    .frame(width: 16, height: 16).position(x: AV.cx, y: 92)
                StarMark().fill(Color(hex: "#a87800")).frame(width: 9, height: 9).position(x: AV.cx, y: 92)
            }
        case "cou.diamants":
            ZStack {
                ChainShape().stroke(Color(hex: "#dff6ff"), lineWidth: 2)
                    .frame(width: 42, height: 26).position(x: AV.cx, y: 80)
                ForEach(0..<5) { i in
                    DiamondMark().fill(Color(hex: "#9fe8ff"))
                        .frame(width: 7, height: 7)
                        .position(x: AV.cx + CGFloat(i - 2) * 9, y: 84 + CGFloat(abs(i - 2)) * 3)
                }
            }
            .shadow(color: Color(hex: "#9fe8ff").opacity(0.6), radius: 3)
        case "cou.cosmique":
            ZStack {
                ChainShape().stroke(Pal.epic, lineWidth: 2)
                    .frame(width: 40, height: 26).position(x: AV.cx, y: 80)
                Circle().fill(RadialGradient(
                    colors: [Color.white, Pal.epic, Color(hex: "#38d6ff")],
                    center: .center, startRadius: 1, endRadius: 10))
                    .frame(width: 16, height: 16).position(x: AV.cx, y: 92)
                    .shadow(color: Pal.epic.opacity(0.8), radius: 5)
            }
        default:
            EmptyView()
        }
    }

    // MARK: Dos (cape / wings / pack, drawn behind the body)

    @ViewBuilder private var backAccessory: some View {
        switch item(.dos) {
        case "dos.sac":
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#3a6ea5"))
                    .frame(width: 82, height: 76).position(x: AV.cx, y: 114)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#2c5580")).frame(width: 10, height: 30).position(x: AV.cx - 36, y: 118)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#2c5580")).frame(width: 10, height: 30).position(x: AV.cx + 36, y: 118)
            }
        case "dos.cape":
            CapeShape().fill(LinearGradient(
                colors: [Theme.bad, Color(hex: "#7a0d1a")], startPoint: .top, endPoint: .bottom))
                .overlay(CapeShape().stroke(Color.black.opacity(0.3), lineWidth: 1))
                .frame(width: 92, height: 86).position(x: AV.cx, y: 112)
        case "dos.katana":
            ZStack {
                Capsule().fill(Color(hex: "#1a1a1a")).frame(width: 6, height: 84)
                    .rotationEffect(.degrees(34)).position(x: AV.cx, y: 104)
                Capsule().fill(Color(hex: "#b8252e")).frame(width: 6, height: 18)
                    .rotationEffect(.degrees(34)).position(x: AV.cx + 24, y: 76)
            }
        case "dos.ailes":
            ZStack {
                WingShape().fill(Color(hex: "#f4f4f4"))
                    .overlay(WingShape().stroke(Color(hex: "#d8d8d8"), lineWidth: 1))
                    .frame(width: 46, height: 72).position(x: AV.cx - 34, y: 104)
                WingShape().fill(Color(hex: "#f4f4f4"))
                    .overlay(WingShape().stroke(Color(hex: "#d8d8d8"), lineWidth: 1))
                    .frame(width: 46, height: 72).scaleEffect(x: -1).position(x: AV.cx + 34, y: 104)
            }
        case "dos.jetpack":
            ZStack {
                Capsule().fill(LinearGradient(colors: [Color(hex: "#c8ccd0"), Color(hex: "#7c858f")],
                                              startPoint: .top, endPoint: .bottom))
                    .frame(width: 14, height: 44).position(x: AV.cx - 30, y: 104)
                Capsule().fill(LinearGradient(colors: [Color(hex: "#c8ccd0"), Color(hex: "#7c858f")],
                                              startPoint: .top, endPoint: .bottom))
                    .frame(width: 14, height: 44).position(x: AV.cx + 30, y: 104)
                FlameShape().fill(LinearGradient(colors: [Color(hex: "#ffe600"), Color(hex: "#ff3b00")],
                                                 startPoint: .top, endPoint: .bottom))
                    .frame(width: 14, height: 18).position(x: AV.cx - 30, y: 134)
                FlameShape().fill(LinearGradient(colors: [Color(hex: "#ffe600"), Color(hex: "#ff3b00")],
                                                 startPoint: .top, endPoint: .bottom))
                    .frame(width: 14, height: 18).position(x: AV.cx + 30, y: 134)
            }
        case "dos.ailesdemon":
            ZStack {
                BatWingShape().fill(LinearGradient(
                    colors: [Color(hex: "#7a0d1a"), Color(hex: "#2a0309")], startPoint: .top, endPoint: .bottom))
                    .frame(width: 48, height: 72).position(x: AV.cx - 36, y: 104)
                    .shadow(color: Theme.bad.opacity(0.5), radius: 4)
                BatWingShape().fill(LinearGradient(
                    colors: [Color(hex: "#7a0d1a"), Color(hex: "#2a0309")], startPoint: .top, endPoint: .bottom))
                    .frame(width: 48, height: 72).scaleEffect(x: -1).position(x: AV.cx + 36, y: 104)
                    .shadow(color: Theme.bad.opacity(0.5), radius: 4)
            }
        default:
            EmptyView()
        }
    }

    // MARK: Main (held item, on the character's side in front)

    @ViewBuilder private var heldItem: some View {
        let hx = AV.cx + 38
        let hy: CGFloat = 122
        switch item(.main) {
        case "main.cafe":
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#f4f4f4"))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.faint, lineWidth: 1))
                    .frame(width: 16, height: 18).position(x: hx, y: hy)
                Circle().stroke(Color(hex: "#f4f4f4"), lineWidth: 2.5).frame(width: 10, height: 10).position(x: hx + 10, y: hy)
                Rectangle().fill(Color.white.opacity(0.4)).frame(width: 2, height: 8).position(x: hx - 3, y: hy - 14)
                Rectangle().fill(Color.white.opacity(0.4)).frame(width: 2, height: 8).position(x: hx + 3, y: hy - 14)
            }
        case "main.ballon":
            ZStack {
                Circle().fill(Color.white).overlay(Circle().stroke(Theme.faint, lineWidth: 1))
                    .frame(width: 22, height: 22).position(x: hx, y: hy)
                PentagonMark().fill(Color.black).frame(width: 9, height: 9).position(x: hx, y: hy)
            }
        case "main.manette":
            ZStack {
                GamepadShape().fill(Color(hex: "#2c2c2c"))
                    .overlay(GamepadShape().stroke(Theme.faint, lineWidth: 1))
                    .frame(width: 30, height: 18).position(x: hx, y: hy)
                Circle().fill(accent).frame(width: 4, height: 4).position(x: hx + 6, y: hy - 1)
                Circle().fill(Theme.bad).frame(width: 4, height: 4).position(x: hx + 10, y: hy - 4)
            }
        case "main.micro":
            ZStack {
                Capsule().fill(Color(hex: "#2c2c2c")).frame(width: 6, height: 22).position(x: hx, y: hy + 6)
                Circle().fill(Pal.gold).overlay(Circle().stroke(Color(hex: "#a87800"), lineWidth: 1))
                    .frame(width: 14, height: 14).position(x: hx, y: hy - 8)
            }
        case "main.baguette":
            ZStack {
                Capsule().fill(Color(hex: "#3a2a1a")).frame(width: 4, height: 30)
                    .rotationEffect(.degrees(20)).position(x: hx, y: hy)
                StarMark().fill(Pal.gold).frame(width: 14, height: 14).position(x: hx + 6, y: hy - 12)
                    .shadow(color: Pal.gold.opacity(0.8), radius: 4)
            }
        case "main.bouclier":
            ZStack {
                ShieldShape().fill(LinearGradient(
                    colors: [Color(hex: "#c8ccd0"), Color(hex: "#7c858f")], startPoint: .top, endPoint: .bottom))
                    .overlay(ShieldShape().stroke(Color(hex: "#5a626b"), lineWidth: 1.5))
                    .frame(width: 26, height: 32).position(x: hx, y: hy)
                Rectangle().fill(Theme.bad).frame(width: 4, height: 18).position(x: hx, y: hy)
                Rectangle().fill(Theme.bad).frame(width: 14, height: 4).position(x: hx, y: hy - 3)
            }
        case "main.epee":
            ZStack {
                BladeShape().fill(LinearGradient(
                    colors: [Color(hex: "#e8edf2"), Color(hex: "#9aa0a6")], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 8, height: 46).position(x: hx, y: hy - 8)
                Rectangle().fill(Pal.gold).frame(width: 20, height: 4).position(x: hx, y: hy + 13)
                Capsule().fill(Color(hex: "#3a2a1a")).frame(width: 5, height: 14).position(x: hx, y: hy + 20)
            }
        case "main.sabre":
            ZStack {
                Capsule().fill(Color(hex: "#9aa0a6")).frame(width: 6, height: 16).position(x: hx, y: hy + 16)
                Capsule().fill(accent).frame(width: 5, height: 46).position(x: hx, y: hy - 8)
                    .shadow(color: accent, radius: 6)
                Capsule().fill(Color.white).frame(width: 2, height: 44).position(x: hx, y: hy - 8)
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Standalone item preview (a mini avatar wearing only this item)

struct AvatarItemPreview: View {
    let item: AvatarItem
    var level: Int = 8
    var scale: CGFloat = 1

    var body: some View {
        AvatarLayeredView(look: AvatarLook(level: level, items: [item.slot: item]),
                          scale: scale, showShadow: false)
    }
}

// MARK: - Store helper

extension PlayerStore {
    /// The player's current avatar: their level plus everything equipped.
    var avatarLook: AvatarLook {
        var items: [AvatarSlot: AvatarItem] = [:]
        for slot in AvatarSlot.allCases {
            if let it = equippedItem(slot: slot) { items[slot] = it }
        }
        return AvatarLook(level: profile.level, items: items)
    }
}

// MARK: - Shapes

private struct SmileShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY * 1.4))
        return p
    }
}

private struct MohawkShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let n = 4
        let w = r.width / CGFloat(n)
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        for i in 0..<n {
            let x0 = r.minX + CGFloat(i) * w
            p.addLine(to: CGPoint(x: x0 + w / 2, y: r.minY + CGFloat(i % 2) * 5))
            p.addLine(to: CGPoint(x: x0 + w, y: r.maxY))
        }
        p.closeSubpath()
        return p
    }
}

private struct CapShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: r.midX, y: r.maxY), radius: r.width / 2,
                 startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct CrownShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.25, y: r.maxY * 0.55))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.75, y: r.maxY * 0.55))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

private struct TieShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.18))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.32))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.18))
        p.closeSubpath()
        p.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.32))
        p.addLine(to: CGPoint(x: r.maxX * 0.78, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.08))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.22, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

private struct ArcBandShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: r.midX, y: r.maxY), radius: r.width / 2,
                 startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        return p
    }
}

// V-neck / open shirt (triangle, apex pointing down)
private struct VNeckShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// Two suit lapels flanking a central V opening, meeting at bottom-center
private struct LapelShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let notch = r.width * 0.16
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX - notch, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.6))
        p.closeSubpath()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + notch, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.6))
        p.closeSubpath()
        return p
    }
}

// Bow tie: two triangles meeting at the center knot
private struct BowTieShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        p.move(to: CGPoint(x: r.midX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// Kimono collar: two crossed bands forming a V, meeting at bottom-center
private struct KimonoCollarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let bw = r.width * 0.16
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + bw, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + bw * 0.4, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX - bw * 0.6, y: r.maxY))
        p.closeSubpath()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - bw, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX - bw * 0.4, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX + bw * 0.6, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// Open camp collar: two triangular flaps with a gap at the neck
private struct CampCollarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX - r.width * 0.06, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX - r.width * 0.18, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.5))
        p.closeSubpath()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.06, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.18, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.5))
        p.closeSubpath()
        return p
    }
}

private struct BananaShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY),
                       control: CGPoint(x: r.midX, y: r.minY - r.height * 0.3))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY),
                       control: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

private struct BraidShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let seg = r.height / 4
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        for i in 0..<4 {
            let y = r.minY + seg * CGFloat(i)
            let x = i % 2 == 0 ? r.maxX : r.minX
            p.addQuadCurve(to: CGPoint(x: r.midX, y: y + seg),
                           control: CGPoint(x: x, y: y + seg / 2))
        }
        return p.strokedPath(.init(lineWidth: r.width, lineCap: .round))
    }
}

private struct MulletShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.18, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - r.width * 0.18, y: r.maxY),
                       control: CGPoint(x: r.midX, y: r.minY + r.height * 0.3))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

private struct FlameShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let n = 3
        let w = r.width / CGFloat(n)
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        for i in 0..<n {
            let x0 = r.minX + CGFloat(i) * w
            p.addQuadCurve(to: CGPoint(x: x0 + w / 2, y: r.minY + CGFloat(i % 2) * 8),
                           control: CGPoint(x: x0, y: r.midY))
            p.addQuadCurve(to: CGPoint(x: x0 + w, y: r.maxY),
                           control: CGPoint(x: x0 + w, y: r.midY))
        }
        p.closeSubpath()
        return p
    }
}

private struct TeardropShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY),
                       control: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

private struct VisorShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY + r.height * 0.25))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.midY + r.height * 0.25),
                       control: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

private struct GridShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 16
        var x = r.minX
        while x <= r.maxX { p.move(to: CGPoint(x: x, y: r.minY)); p.addLine(to: CGPoint(x: x, y: r.maxY)); x += step }
        var y = r.minY
        while y <= r.maxY { p.move(to: CGPoint(x: r.minX, y: y)); p.addLine(to: CGPoint(x: r.maxX, y: y)); y += step }
        return p
    }
}

private struct SpiralShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        for arm in 0..<2 {
            var first = true
            var a = Double(arm) * .pi
            while a < .pi * 4 {
                let radius = a * 4
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * CGFloat(radius),
                                 y: c.y + CGFloat(sin(a)) * CGFloat(radius))
                if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
                a += 0.25
            }
        }
        return p
    }
}

private struct StarMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) / 2
        let inner = outer * 0.45
        for i in 0..<10 {
            let angle = -.pi / 2 + Double(i) * .pi / 5
            let radius = i % 2 == 0 ? outer : inner
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * radius,
                             y: c.y + CGFloat(sin(angle)) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

private struct DiamondMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

private struct Scanlines: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        var y = r.minY
        while y < r.maxY {
            p.move(to: CGPoint(x: r.minX, y: y))
            p.addLine(to: CGPoint(x: r.maxX, y: y))
            y += 4
        }
        return p
    }
}

private struct SynthGrid: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let horizon = r.midY + 12
        var y = horizon
        var gap: CGFloat = 6
        while y < r.maxY {
            p.move(to: CGPoint(x: r.minX, y: y))
            p.addLine(to: CGPoint(x: r.maxX, y: y))
            y += gap; gap += 3
        }
        let vp = CGPoint(x: r.midX, y: horizon)
        var x = r.minX
        while x <= r.maxX {
            p.move(to: CGPoint(x: x, y: r.maxY))
            p.addLine(to: vp)
            x += 20
        }
        return p
    }
}

private struct HornShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY),
                       control: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                       control: CGPoint(x: r.midX + r.width * 0.3, y: r.midY))
        p.closeSubpath()
        return p
    }
}

private struct HeartMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let top = r.minY + h * 0.28
        p.move(to: CGPoint(x: r.midX, y: top))
        p.addCurve(to: CGPoint(x: r.minX, y: top),
                   control1: CGPoint(x: r.midX - w * 0.1, y: r.minY),
                   control2: CGPoint(x: r.minX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.minX, y: r.minY + h * 0.6),
                   control2: CGPoint(x: r.midX - w * 0.2, y: r.minY + h * 0.75))
        p.addCurve(to: CGPoint(x: r.maxX, y: top),
                   control1: CGPoint(x: r.midX + w * 0.2, y: r.minY + h * 0.75),
                   control2: CGPoint(x: r.maxX, y: r.minY + h * 0.6))
        p.addCurve(to: CGPoint(x: r.midX, y: top),
                   control1: CGPoint(x: r.maxX, y: r.minY),
                   control2: CGPoint(x: r.midX + w * 0.1, y: r.minY))
        p.closeSubpath()
        return p
    }
}

private struct CheckerShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 20
        var row = 0
        var y = r.minY
        while y < r.maxY {
            var col = 0
            var x = r.minX
            while x < r.maxX {
                if (row + col) % 2 == 0 {
                    p.addRect(CGRect(x: x, y: y, width: step, height: step))
                }
                x += step; col += 1
            }
            y += step; row += 1
        }
        return p
    }
}

private struct AuroraShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let top = r.minY + r.height * 0.15
        p.move(to: CGPoint(x: r.minX, y: top + 20))
        p.addCurve(to: CGPoint(x: r.maxX, y: top + 24),
                   control1: CGPoint(x: r.width * 0.33, y: top - 12),
                   control2: CGPoint(x: r.width * 0.66, y: top + 50))
        p.addLine(to: CGPoint(x: r.maxX, y: top + 60))
        p.addCurve(to: CGPoint(x: r.minX, y: top + 56),
                   control1: CGPoint(x: r.width * 0.66, y: top + 86),
                   control2: CGPoint(x: r.width * 0.33, y: top + 24))
        p.closeSubpath()
        return p
    }
}

private struct TriangleDown: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

private struct ChainShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY))
        return p
    }
}

private struct PentagonMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) / 2
        for i in 0..<5 {
            let angle = -.pi / 2 + Double(i) * 2 * .pi / 5
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * radius,
                             y: c.y + CGFloat(sin(angle)) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

private struct GamepadShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let rad = r.height * 0.5
        p.addRoundedRect(in: r, cornerSize: CGSize(width: rad, height: rad))
        return p
    }
}

private struct ShieldShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.55))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.maxY * 0.95))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.55),
                       control: CGPoint(x: r.minX, y: r.maxY * 0.95))
        p.closeSubpath()
        return p
    }
}

private struct BladeShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let tip = r.height * 0.12
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + tip))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + tip))
        p.closeSubpath()
        return p
    }
}

private struct CapeShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.3, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.3, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        let n = 4
        let step = r.width / CGFloat(n)
        for i in 0..<n {
            let nx = r.maxX - step * CGFloat(i + 1)
            p.addQuadCurve(to: CGPoint(x: nx, y: r.maxY),
                           control: CGPoint(x: nx + step / 2, y: r.maxY - r.height * 0.09))
        }
        p.closeSubpath()
        return p
    }
}

private struct WingShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.midY * 0.9),
                       control: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.34, y: r.maxY * 0.78),
                       control: CGPoint(x: r.minX + 2, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.64, y: r.maxY * 0.88),
                       control: CGPoint(x: r.minX + r.width * 0.40, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.minX + r.width * 0.72, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

private struct BatWingShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.2))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.3, y: r.maxY),
                       control: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.55, y: r.maxY * 0.7),
                       control: CGPoint(x: r.minX + r.width * 0.42, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.8, y: r.maxY),
                       control: CGPoint(x: r.minX + r.width * 0.67, y: r.maxY * 0.78))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.minX + r.width * 0.9, y: r.maxY * 0.5))
        p.closeSubpath()
        return p
    }
}

// MARK: - Preview

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 16) {
            ForEach([1, 6, 11, 16, 20], id: \.self) { lvl in
                VStack {
                    AvatarLayeredView(look: AvatarLook(level: lvl), scale: 0.9)
                    Text("Niv. \(lvl)").font(KFont.mono(10)).foregroundStyle(Theme.muted)
                }
            }
            VStack {
                AvatarLayeredView(look: AvatarLook(level: 14, items: [
                    .tete: AvatarItem.item(id: "tete.couronne")!,
                    .lunettes: AvatarItem.item(id: "lunettes.neon")!,
                    .haut: AvatarItem.item(id: "haut.costume")!,
                    .fond: AvatarItem.item(id: "fond.synthwave")!,
                    .cadre: AvatarItem.item(id: "cadre.or")!,
                ]), scale: 0.9)
                Text("Équipé").font(KFont.mono(10)).foregroundStyle(Theme.muted)
            }
        }
        .padding()
    }
    .background(Theme.bg)
    .environment(\.accent, Theme.Accent.vert.color)
}

import SwiftUI

/// La roue quotidienne, façon machine à sous: un tour par jour, gain en pièces
/// tiré d'une table pondérée (graine du jour, donc identique pour tout le monde et
/// reproductible). Le rouleau défile puis ralentit pour s'arrêter sur le gain.
struct DailyWheelView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent

    @State private var won: Int?
    @State private var spinning = false
    @State private var revealed = false
    @State private var strip: [Int] = SlotReel.makeStrip(landing: 20)
    @State private var spinID = 0

    private var jackpot: Int { DailyWheel.prizes.map(\.coins).max() ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: "Roue du jour")
            ScrollView {
                VStack(spacing: 12) {
                    machine
                    prizeTable
                    spinButton
                }
                .screenPadding()
                .padding(.vertical, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .screenBackground()
    }

    // MARK: Machine à sous

    private var machine: some View {
        VStack(spacing: 10) {
            statusLabel

            SlotReel(strip: strip, spinID: $spinID, jackpot: jackpot) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    spinning = false
                    revealed = true
                }
                Haptics.notify(.success)
                if won == jackpot { Haptics.impact(.heavy) }
            }

            if revealed, let won {
                CoinLabel(amount: won, color: won == jackpot ? Color(hex: "#ffb000") : nil)
                    .scaleEffect(1.15)
                    .transition(.scale.combined(with: .opacity))
            } else if !store.wheelAvailable && !spinning {
                Text("Reviens demain")
                    .font(KFont.body(13)).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .kPanel()
    }

    @ViewBuilder private var statusLabel: some View {
        if spinning {
            SectionLabel("Ça tourne…")
        } else if revealed {
            SectionLabel(won == jackpot ? "JACKPOT !" : "Gain")
        } else if store.wheelAvailable {
            SectionLabel("Tente ta chance")
        } else {
            SectionLabel("Déjà tournée")
        }
    }

    // MARK: Table des lots

    private var prizeTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Lots possibles")
                .padding(.bottom, 10)
            ForEach(Array(DailyWheel.prizes.enumerated()), id: \.offset) { index, prize in
                let isJackpot = prize.coins == jackpot
                HStack {
                    Text(chanceText(prize.weight))
                        .font(KFont.mono(11))
                        .foregroundStyle(Theme.muted)
                    if isJackpot {
                        Text("JACKPOT")
                            .font(KFont.mono(9, bold: true)).tracking(1)
                            .foregroundStyle(Color(hex: "#ffb000"))
                            .padding(.vertical, 2).padding(.horizontal, 5)
                            .overlay(Rectangle().stroke(Color(hex: "#ffb000"), lineWidth: 1))
                    }
                    Spacer()
                    CoinLabel(amount: prize.coins, color: isJackpot ? Color(hex: "#ffb000") : nil)
                }
                .padding(.vertical, 6)
                if index < DailyWheel.prizes.count - 1 {
                    Divider().overlay(Theme.border)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kPanel()
    }

    /// Convertit un poids (sur 10 000) en pourcentage lisible: "30%", "2.5%",
    /// "0.4%", "0.01%". Les zéros de fin sont retirés.
    private func chanceText(_ weight: Int) -> String {
        let p = Double(weight) / Double(DailyWheel.totalWeight) * 100
        var s = String(format: "%.2f", p)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s + "%"
    }

    // MARK: Bouton

    @ViewBuilder private var spinButton: some View {
        if spinning {
            PixelButton(title: "…", style: .ghost) {}
                .opacity(0.6)
                .disabled(true)
        } else if store.wheelAvailable {
            PixelButton(title: "Tourner") { startSpin() }
        } else {
            PixelButton(title: "Reviens demain", style: .ghost) {}
                .opacity(0.5)
                .disabled(true)
        }
    }

    private func startSpin() {
        guard store.wheelAvailable, !spinning else { return }
        let amount = store.spinWheel()
        won = amount
        strip = SlotReel.makeStrip(landing: amount)
        withAnimation(.easeOut(duration: 0.15)) { revealed = false }
        spinning = true
        Haptics.impact(.light)
        spinID += 1
    }
}

// MARK: - Rouleau de machine à sous

/// Un rouleau vertical qui défile vite puis ralentit (easeOut) pour s'arrêter,
/// avec le gain centré sur la ligne de paiement. L'arrêt est piloté par `spinID`:
/// l'écran incrémente cette valeur après avoir mis à jour `strip` (dont l'avant-
/// dernier élément est le gain à afficher).
private struct SlotReel: View {
    let strip: [Int]
    @Binding var spinID: Int
    let jackpot: Int
    var onFinish: () -> Void

    @Environment(\.accent) private var accent
    @State private var offset: CGFloat = 0

    private static let rowHeight: CGFloat = 40
    private static let visibleRows = 3
    private static var windowHeight: CGFloat { rowHeight * CGFloat(visibleRows) }

    /// Le gain est placé en avant-dernière position pour qu'une case reste visible
    /// sous la ligne de paiement à l'arrêt.
    private var landingIndex: Int { max(0, strip.count - 2) }

    /// Décalage vertical qui place `index` sur la ligne de paiement. La pile de
    /// cases est centrée par le ZStack, donc on part du centre de la pile (case
    /// (n-1)/2) et on compense pour amener `index` au centre de la fenêtre.
    private func centeredOffset(_ index: Int) -> CGFloat {
        Self.rowHeight * (CGFloat(strip.count - 1) / 2 - CGFloat(index))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(strip.indices, id: \.self) { i in
                    row(strip[i])
                }
            }
            .frame(maxWidth: .infinity)
            .offset(y: offset)

            // Dégradé haut/bas: les cases hors ligne de paiement s'estompent.
            VStack(spacing: 0) {
                LinearGradient(colors: [Theme.surface, Theme.surface.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.rowHeight)
                Spacer(minLength: 0)
                LinearGradient(colors: [Theme.surface.opacity(0), Theme.surface],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.rowHeight)
            }
            .allowsHitTesting(false)

            // Ligne de paiement + repères latéraux.
            HStack {
                Image(systemName: "arrowtriangle.right.fill")
                Spacer()
                Image(systemName: "arrowtriangle.left.fill")
            }
            .font(.system(size: 11))
            .foregroundStyle(accent)
            .padding(.horizontal, 4)
            Rectangle().stroke(accent, lineWidth: 2)
                .frame(height: Self.rowHeight)
        }
        .frame(height: Self.windowHeight)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipped()
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
        .onAppear { offset = centeredOffset(1) }
        .onChange(of: spinID) { _, _ in runSpin() }
    }

    private func row(_ coins: Int) -> some View {
        let color: Color = coins == jackpot ? Color(hex: "#ffb000") : accent
        return HStack(spacing: 8) {
            Circle().strokeBorder(color, lineWidth: 2).frame(width: 15, height: 15)
            Text("\(coins)")
                .font(KFont.mono(22, bold: true))
                .foregroundStyle(color)
        }
        .frame(height: Self.rowHeight)
        .frame(maxWidth: .infinity)
    }

    private func runSpin() {
        // Remet le rouleau en haut sans animation, puis lance la descente animée
        // au tick suivant pour qu'elle reparte bien du début à chaque tour.
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { offset = centeredOffset(1) }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 3.0)) {
                offset = centeredOffset(landingIndex)
            } completion: {
                onFinish()
            }
        }
    }

    /// Construit la bande défilante: des cases de remplissage tirées de la table,
    /// puis le gain (avant-dernière case), puis une case de remplissage finale.
    static func makeStrip(landing: Int) -> [Int] {
        let pool = DailyWheel.prizes.map(\.coins)
        var strip = (0..<38).map { _ in pool.randomElement() ?? landing }
        strip.append(landing)
        strip.append(pool.randomElement() ?? landing)
        return strip
    }
}

#Preview {
    let store = PlayerStore()
    return NavigationStack { DailyWheelView() }
        .environment(store)
        .environment(Router(store: store))
        .environment(\.accent, store.accentColor)
}

import SwiftUI

/// End-of-match screen: win/lose, the rating + tier movement, the player's gains,
/// and the final score. Reached when the controller's match phase is `.finished`.
struct RankedResultsView: View {
    let controller: RankedController
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    private var title: String {
        switch controller.outcome {
        case .won: return "VICTOIRE"
        case .lost: return "DÉFAITE"
        case .draw: return "ÉGALITÉ"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(title)
                    .font(KFont.mono(13, bold: true)).tracking(2)
                    .foregroundStyle(controller.outcome == .won ? accent : Theme.text)
                    .padding(.top, 24)

                ratingStrip
                scoreLine
                if let result = controller.localResult { gains(result) }

                PixelButton(title: "Retour") { router.endRanked() }
                    .padding(.top, 4)
            }
            .screenPadding()
            .padding(.vertical, 18)
        }
        .screenBackground()
    }

    private var ratingStrip: some View {
        VStack(spacing: 10) {
            SectionLabel("Classement")
            HStack(spacing: 12) {
                tierBadge(controller.tierBefore, rating: controller.ratingBefore)
                Image(systemName: "arrow.right").font(.system(size: 12)).foregroundStyle(Theme.muted)
                if let after = controller.tierAfter, let rating = controller.ratingAfter {
                    tierBadge(after, rating: rating)
                }
            }
            if let delta = controller.ratingDelta {
                Text(delta >= 0 ? "+\(delta) ELO" : "\(delta) ELO")
                    .font(KFont.mono(13, bold: true))
                    .foregroundStyle(delta >= 0 ? accent : Theme.bad)
            }
        }
        .frame(maxWidth: .infinity)
        .kPanel(16)
    }

    private func tierBadge(_ tier: RankTier, rating: Int) -> some View {
        VStack(spacing: 4) {
            Text(tier.title.uppercased())
                .font(KFont.mono(11, bold: true)).tracking(1)
                .foregroundStyle(Color(hex: tier.colorHex))
            Text("\(rating)").font(KFont.mono(13, bold: true)).foregroundStyle(Theme.text)
        }
    }

    private var scoreLine: some View {
        HStack(spacing: 12) {
            Text(controller.me?.pseudo ?? "Toi")
                .font(KFont.mono(13, bold: true)).foregroundStyle(accent).lineLimit(1)
            Spacer()
            Text("\(controller.scoreMe) - \(controller.scoreOpponent)")
                .font(KFont.mono(16, bold: true)).foregroundStyle(Theme.text)
            Spacer()
            Text(controller.opponent?.pseudo ?? "Adversaire")
                .font(KFont.mono(13, bold: true)).foregroundStyle(Theme.text).lineLimit(1)
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(Theme.surface)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }

    private func gains(_ result: GameResult) -> some View {
        VStack(spacing: 0) {
            row("Bonnes réponses", "\(result.correctCount)/\(result.total)")
            Divider().overlay(Theme.border)
            row("Pièces", result.coinsEarned >= 0 ? "+\(result.coinsEarned)" : "\(result.coinsEarned)", highlight: true)
            Divider().overlay(Theme.border)
            row("XP", "+\(result.xpEarned)")
            if let chests = controller.localApplied?.chestsEarned, chests > 0 {
                Divider().overlay(Theme.border)
                row(chests > 1 ? "Coffres" : "Coffre", "+\(chests)", highlight: true)
            }
        }
        .background(Theme.surface)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }

    private func row(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label).font(KFont.mono(12)).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).font(KFont.mono(13, bold: true)).foregroundStyle(highlight ? accent : Theme.text)
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
    }
}

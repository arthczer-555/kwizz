import SwiftUI

struct ResultsView: View {
    let game: GameController
    let result: GameResult
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent
    @State private var showLevelUp: Bool

    init(game: GameController, result: GameResult) {
        self.game = game
        self.result = result
        _showLevelUp = State(initialValue: !(game.appliedResult?.leveledUpTo.isEmpty ?? true))
    }

    var body: some View {
        ZStack {
            resultsContent
            if showLevelUp, let applied = game.appliedResult, let level = applied.leveledUpTo.last {
                LevelUpView(level: level,
                            rewardCoins: applied.levelRewardCoins,
                            gotItem: !applied.levelRewardItems.isEmpty) {
                    withAnimation(.easeInOut(duration: 0.2)) { showLevelUp = false }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showLevelUp)
    }

    private var resultsContent: some View {
        VStack(spacing: 14) {
            Spacer()
            Text(title)
                .font(KFont.mono(12, bold: true)).tracking(2)
                .foregroundStyle(result.isNewRecord ? accent : Theme.text)

            SectionLabel("Score")
            ScoreText(value: result.score, size: 52)
            Text("/ \(result.maxScore)").font(KFont.mono(12)).foregroundStyle(Theme.muted)

            VStack(spacing: 0) {
                ResultRow(label: "Bonnes réponses", value: "\(result.correctCount)/\(result.total)", color: accent)
                Divider().overlay(Theme.border)
                ResultRow(label: "Pièces", value: coinsString, color: accent, isCoin: true)
                Divider().overlay(Theme.border)
                ResultRow(label: "XP", value: "+\(result.xpEarned)")
                if result.bestStreak > 1 {
                    Divider().overlay(Theme.border)
                    ResultRow(label: "Meilleure série", value: "\(result.bestStreak)")
                }
                if let won = result.duelWon {
                    Divider().overlay(Theme.border)
                    ResultRow(label: "Duel", value: won ? "GAGNÉ" : "PERDU", color: won ? accent : Theme.bad)
                }
                if let chests = game.appliedResult?.chestsEarned, chests > 0 {
                    Divider().overlay(Theme.border)
                    ResultRow(label: chests > 1 ? "Coffres gagnés" : "Coffre gagné", value: "+\(chests)", color: accent)
                }
            }
            .background(Theme.surface)
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
            .padding(.top, 8)

            if let ids = game.appliedResult?.newlyUnlockedAchievementIDs, !ids.isEmpty {
                VStack(spacing: 6) {
                    SectionLabel("Succès débloqué")
                    ForEach(ids, id: \.self) { id in
                        if let ach = Achievement.find(id) {
                            Text(ach.title).font(KFont.mono(13, bold: true)).foregroundStyle(accent)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .kPanel()
                .padding(.top, 8)
            }

            Spacer()

            PixelButton(title: "Rejouer") { replay() }
            PixelButton(title: "Accueil", style: .ghost) { router.goHome() }
        }
        .screenPadding()
        .padding(.vertical, 18)
        .screenBackground()
    }

    private var title: String {
        if result.isNewRecord { return "★ NOUVEAU RECORD ★" }
        if let won = result.duelWon { return won ? "VICTOIRE" : "DOMMAGE" }
        return "BIEN JOUÉ"
    }

    private var coinsString: String {
        let delta = game.appliedResult?.coinsDelta ?? result.coinsEarned
        return delta >= 0 ? "+\(delta)" : "\(delta)"
    }

    private func replay() {
        router.startGame(
            mode: result.mode,
            category: result.categoryID.flatMap { Category.find(id: $0) },
            subcategory: nil,
            difficulty: result.difficulty
        )
    }
}

private struct ResultRow: View {
    let label: String
    let value: String
    var color: Color = Theme.text
    var isCoin: Bool = false
    @Environment(\.accent) private var accent

    var body: some View {
        HStack {
            Text(label).font(KFont.body(14)).foregroundStyle(Theme.text)
            Spacer()
            HStack(spacing: 5) {
                if isCoin {
                    Circle().strokeBorder(color, lineWidth: 1.5).frame(width: 9, height: 9)
                }
                Text(value).font(KFont.mono(13, bold: true)).foregroundStyle(color)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
    }
}

struct LevelUpView: View {
    let level: Int
    let rewardCoins: Int
    let gotItem: Bool
    let onContinue: () -> Void
    @Environment(\.accent) private var accent

    var body: some View {
        ZStack {
            Color.black.opacity(0.93).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("LEVEL UP").font(KFont.mono(13, bold: true)).tracking(3).foregroundStyle(accent)
                ScoreText(value: level, size: 56)
                AvatarLayeredView(look: AvatarLook(level: level), scale: 0.7, showShadow: false, ring: accent)
                VStack(spacing: 8) {
                    SectionLabel("Nouveau titre")
                    Text(LevelTable.title(level: level))
                        .font(KFont.mono(16)).foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .kPanel()
                HStack(spacing: 30) {
                    if rewardCoins > 0 {
                        VStack(spacing: 5) { CoinLabel(amount: rewardCoins); SectionLabel("Pièces") }
                    }
                    if gotItem {
                        VStack(spacing: 5) {
                            Image(systemName: "gift.fill").foregroundStyle(accent)
                            SectionLabel("Item")
                        }
                    }
                }
                PixelButton(title: "Continuer") { onContinue() }
            }
            .padding(28)
        }
    }
}

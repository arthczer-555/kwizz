import SwiftUI

struct HomeView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    var body: some View {
        // Tout doit tenir sans scroll, du SE au Pro Max : on propose plusieurs
        // versions du même écran (avatar + espacements de plus en plus serrés)
        // et SwiftUI garde la première qui rentre dans la hauteur disponible.
        // Les variantes sont listées une à une : un `ForEach` ne compterait que
        // pour un seul candidat et ViewThatFits ne testerait rien. La dernière
        // sert de filet (retenue même si elle déborde), d'où la plus serrée.
        ViewThatFits(in: .vertical) {
            content(avatarScale: 1.55, gap: 18)
            content(avatarScale: 1.40, gap: 16)
            content(avatarScale: 1.30, gap: 16)
            content(avatarScale: 1.15, gap: 14)
            content(avatarScale: 1.00, gap: 12)
            content(avatarScale: 0.85, gap: 10)
            content(avatarScale: 0.70, gap: 8)
            content(avatarScale: 0.58, gap: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .screenBackground()
    }

    @ViewBuilder
    private func content(avatarScale: CGFloat, gap: CGFloat) -> some View {
        VStack(spacing: gap) {
            TopBar(coins: store.profile.coins, level: store.profile.level)

            Spacer(minLength: 0)

            // Hero: avatar + identity
            VStack(spacing: gap * 0.6) {
                NavigationLink(value: Route.avatar) {
                    AvatarLayeredView(look: store.avatarLook, scale: avatarScale)
                }
                .buttonStyle(.plain)

                Text(store.profile.pseudo)
                    .font(KFont.mono(18, bold: true))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            // XP block
            VStack(spacing: 6) {
                HStack {
                    SectionLabel("LVL \(store.profile.level)")
                    Spacer()
                    SectionLabel(
                        store.profile.levelProgress.isMax
                            ? "MAX"
                            : "\(store.profile.levelProgress.xpIntoLevel) / \(store.profile.levelProgress.xpForNextLevel) XP"
                    )
                }
                XPBar(fraction: store.profile.levelProgress.fraction)
            }

            Spacer(minLength: 0)

            // Play
            PixelButton(title: "Jouer") { router.goToPlay() }

            // Rendez-vous du jour. Le compte à rebours vers minuit remplace un
            // « demain » qui ne dit pas quand : seul ce bloc se rafraîchit à la
            // seconde, le reste de l'écran ne redessine pas.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: gap * 0.65) {
                    dailyCard(now: context.date)
                    HStack(spacing: 10) {
                        NavigationLink(value: Route.chestOpen) { chestTile }
                            .buttonStyle(.plain)
                        NavigationLink(value: Route.dailyWheel) { wheelTile(now: context.date) }
                            .buttonStyle(.plain)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .screenPadding()
        .padding(.vertical, gap)
    }

    // MARK: - Défi du jour

    @ViewBuilder private func dailyCard(now: Date) -> some View {
        let available = store.dailyAvailable
        NavigationLink(value: Route.defiIntro) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    SectionLabel("Défi du jour")
                    // Gain et condition sur une seule ligne. Le badge « 1 essai »
                    // coûtait une ligne entière pour une information que l'écran
                    // d'intro du défi rappelle de toute façon avant de lancer.
                    HStack(spacing: 6) {
                        CoinLabel(amount: available ? Economy.defiReward(errors: 0)
                                                    : store.profile.lastDailyReward,
                                  color: available ? nil : Theme.muted,
                                  size: 15)
                        Text(available
                                ? "pour \(DailyChallenge.questionCount) bonnes réponses"
                                : dailyDoneSubtitle(now: now))
                            .font(KFont.body(11.5))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 6)
                MiniAction(title: available ? "Jouer" : "Détail", filled: available)
            }
            .actionPanel(active: available)
        }
        .buttonStyle(.plain)
    }

    /// « 9/10, retour dans 07:42:11 ». Sans score enregistré (app tuée pendant le
    /// défi), on le dit plutôt que d'afficher un faux 0/10.
    private func dailyDoneSubtitle(now: Date) -> String {
        let correct = store.profile.lastDailyCorrect
        let prefix = correct >= 0 ? "\(correct)/\(DailyChallenge.questionCount)" : "tentative perdue"
        return "\(prefix), retour dans \(Self.timeUntilMidnight(from: now))"
    }

    // MARK: - Coffres & roue

    private var chestTile: some View {
        let count = store.profile.ownedChests
        return rewardTile(
            icon: "shippingbox.fill",
            title: "Coffres",
            value: count == 0 ? "Aucun" : (count == 1 ? "1 prêt" : "\(count) prêts"),
            // La chance de coffre monte avec le score (rien en dessous de 60 % de
            // réussite), donc on invite à bien jouer, pas à enchaîner les parties.
            action: count > 0 ? "Ouvrir" : "Gagne-les en jouant",
            active: count > 0
        )
    }

    private func wheelTile(now: Date) -> some View {
        let available = store.wheelAvailable
        return rewardTile(
            icon: "circle.hexagongrid.fill",
            title: "Roue",
            value: available ? "1 tour" : "Fait",
            action: available ? "Tourner" : "Retour \(Self.timeUntilMidnight(from: now))",
            active: available
        )
    }

    @ViewBuilder private func rewardTile(icon: String, title: String, value: String,
                                         action: String, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(active ? accent : Theme.muted)
                SectionLabel(title)
                Spacer()
            }
            Text(value)
                .font(KFont.mono(active ? 15 : 13, bold: active))
                .foregroundStyle(active ? Theme.text : Theme.muted)
            Spacer(minLength: 2)
            // Ligne d'action : c'est elle qui dit que la tuile est un bouton.
            VStack(spacing: 6) {
                Rectangle()
                    .fill(active ? accent : Theme.faint)
                    .frame(height: 1)
                HStack(spacing: 4) {
                    Text(action.uppercased())
                        .font(KFont.mono(9)).tracking(1.2)
                        .foregroundStyle(active ? accent : Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 2)
                    if active {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(accent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .kPanel(11)
    }

    /// Temps restant avant la remise à zéro quotidienne (minuit local).
    static func timeUntilMidnight(from now: Date) -> String {
        let cal = Calendar.current
        guard let midnight = cal.nextDate(after: now,
                                          matching: DateComponents(hour: 0, minute: 0, second: 0),
                                          matchingPolicy: .nextTime) else { return "00:00:00" }
        let seconds = max(0, Int(midnight.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}

// MARK: - Pièces d'accueil

/// Petit bouton logé dans une carte : assez visible pour dire « ça se tape »,
/// assez discret pour ne pas concurrencer le bouton Jouer plein écran.
private struct MiniAction: View {
    let title: String
    var filled: Bool = true
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(KFont.mono(10, bold: filled))
                .tracking(1.5)
            if filled {
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(filled ? Theme.accentInk : Theme.muted)
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(filled ? accent : Color.clear)
        .overlay(Rectangle().stroke(filled ? accent : Theme.faint, lineWidth: 1))
    }
}

/// Panneau d'action : un `kPanel` doublé d'une barre d'accent à gauche, qui
/// s'éteint quand il n'y a plus rien à faire aujourd'hui.
private struct ActionPanel: ViewModifier {
    let active: Bool
    @Environment(\.accent) private var accent

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(active ? accent : Theme.faint)
                    .frame(width: 3)
            }
    }
}

private extension View {
    func actionPanel(active: Bool) -> some View { modifier(ActionPanel(active: active)) }
}

#Preview {
    let store = PlayerStore()
    return NavigationStack {
        HomeView()
    }
    .environment(store)
    .environment(Router(store: store))
    .environment(\.accent, store.accentColor)
}

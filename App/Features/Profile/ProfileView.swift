import SwiftUI

struct ProfileView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent
    @State private var editingPseudo = false

    private let columns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
    private let statColumns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("PROFIL").font(KFont.mono(13, bold: true))
                    Spacer()
                    NavigationLink(value: Route.settings) {
                        Image(systemName: "gearshape").foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 8) {
                    NavigationLink(value: Route.avatar) {
                        AvatarLayeredView(look: store.avatarLook, scale: 1.0)
                    }
                    .buttonStyle(.plain)
                    Button { editingPseudo = true } label: {
                        HStack(spacing: 5) {
                            Text(store.profile.pseudo).font(KFont.mono(16, bold: true))
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .buttonStyle(.plain)
                    Text("Niveau \(store.profile.level)")
                        .font(KFont.body(13))
                        .foregroundStyle(Theme.muted)
                    XPBar(fraction: store.profile.levelProgress.fraction)
                }

                LazyVGrid(columns: statColumns, spacing: 9) {
                    stat("Parties", "\(store.profile.gamesPlayed)")
                    stat("% Bonnes", "\(Int(store.profile.accuracy * 100))")
                    stat("Série max", "\(store.profile.bestStreakEver)")
                }

                HStack { SectionLabel("Records par mode"); Spacer() }

                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(GameMode.allCases.filter(\.tracksRecord)) { mode in
                        record(mode)
                    }
                }

                HStack {
                    SectionLabel("Score par thème")
                    Spacer()
                    NavigationLink(value: Route.themeStats) {
                        Text("voir →").font(KFont.mono(11)).foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    SectionLabel("Succès")
                    Spacer()
                    NavigationLink(value: Route.achievements) {
                        Text("tout voir →").font(KFont.mono(11)).foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .screenPadding()
        }
        .screenBackground()
        .sheet(isPresented: $editingPseudo) {
            PseudoEditSheet(current: store.profile.pseudo)
                .environment(store)
                .environment(\.accent, accent)
        }
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: String) -> some View {
        VStack {
            Text(value).font(KFont.mono(17)).foregroundStyle(accent)
            SectionLabel(label)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .kPanel()
    }

    @ViewBuilder
    private func record(_ mode: GameMode) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: mode.symbol).font(.system(size: 12)).foregroundStyle(Theme.muted)
                SectionLabel(mode.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            HStack {
                Text(recordValue(mode))
                    .font(KFont.mono(17))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .kPanel()
    }

    /// Most modes display their best score; duel shows wins over total played, the
    /// daily challenge shows how many have been finished and survie counts the
    /// questions chained before the first mistake.
    private func recordValue(_ mode: GameMode) -> String {
        switch mode {
        case .duel:
            return "\(store.profile.duelWins)/\(store.profile.duelGames) gagnés"
        case .defi:
            return "\(store.profile.defiCompletedCount) fini\(store.profile.defiCompletedCount > 1 ? "s" : "")"
        case .survie:
            let best = store.profile.bestScore(forMode: mode)
            return best > 0 ? "\(best) d'affilée" : "-"
        default:
            let best = store.profile.bestScore(forMode: mode)
            return best > 0 ? "\(best)" : "-"
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(PlayerStore())
}

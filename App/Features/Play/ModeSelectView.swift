import SwiftUI

struct ModeSelectView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.accent) private var accent

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Text("CHOISIS TON MODE")
                        .font(KFont.mono(13, bold: true))
                        .tracking(1)
                        .foregroundStyle(accent)
                    Spacer()
                    CoinLabel(amount: store.profile.coins)
                }
                .padding(.bottom, 14)

                ForEach(Array(GameMode.allCases.enumerated()), id: \.element) { idx, mode in
                    if idx > 0 {
                        Divider().overlay(Theme.border)
                    }
                    if mode.comingSoon {
                        ModeRow(mode: mode, accent: accent, comingSoon: true)
                    } else if mode == .defi {
                        // Le défi mène à son écran d'intro ; le classement mensuel
                        // reste accessible via l'onglet Classement.
                        NavigationLink(value: Route.defiIntro) {
                            ModeRow(mode: mode, accent: accent, comingSoon: false)
                        }
                        .buttonStyle(.plain)
                    } else if mode == .entrainement {
                        // Seul mode avec choix : thème puis difficulté.
                        NavigationLink(value: Route.category(mode)) {
                            ModeRow(mode: mode, accent: accent, comingSoon: false)
                        }
                        .buttonStyle(.plain)
                    } else if mode == .duel {
                        // Duel en ligne : écran de création / rejoindre via un code.
                        NavigationLink(value: Route.duelEntry) {
                            ModeRow(mode: mode, accent: accent, comingSoon: false)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Modes standards : tout mélangé, aucune sélection, on lance direct.
                        Button {
                            router.startGame(mode: mode, category: nil, subcategory: nil, difficulty: .normal)
                        } label: {
                            ModeRow(mode: mode, accent: accent, comingSoon: false)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Compétition en ligne (hors GameMode) : la ligue classée, mise en
                // avant par un petit contour doré.
                Button { router.openRanked() } label: {
                    HStack {
                        Image(systemName: "trophy.fill").frame(width: 24).foregroundStyle(Color(hex: "#ffd700"))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ligue 1v1").font(KFont.mono(13))
                            Text("Classé").font(KFont.body(12)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color(hex: "#ffd700"))
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .overlay(Rectangle().stroke(Color(hex: "#ffd700"), lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, -12)
                .padding(.top, 12)
            }
            .screenPadding()
            .padding(.vertical, 16)
        }
        .screenBackground()
    }
}

private struct ModeRow: View {
    let mode: GameMode
    let accent: Color
    let comingSoon: Bool

    var body: some View {
        HStack {
            Image(systemName: mode.symbol)
                .frame(width: 24)
                .foregroundStyle(comingSoon ? Theme.muted : accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.title)
                    .font(KFont.mono(13))
                Text(mode.subtitle)
                    .font(KFont.body(12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if comingSoon {
                Text("À SUIVRE")
                    .font(KFont.mono(9))
                    .tracking(1)
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(accent)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .opacity(comingSoon ? 0.55 : 1)
    }
}

#Preview {
    NavigationStack {
        ModeSelectView()
            .environment(PlayerStore())
            .environment(\.accent, Theme.Accent.vert.color)
    }
}

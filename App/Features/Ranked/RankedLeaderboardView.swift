import SwiftUI

/// Une ligne de classement (rang, pseudo, rating), surlignée quand c'est le joueur.
/// Partagée par l'aperçu de la ladder et le classement général.
struct RankedRow: View {
    @Environment(\.accent) private var accent
    let entry: SupabaseService.RankedLeaderboardEntry
    let isMe: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(KFont.mono(13, bold: true))
                .foregroundStyle(entry.rank <= 3 ? accent : Theme.muted)
                .frame(minWidth: 30, alignment: .leading)
            Text(entry.pseudo).font(KFont.mono(13, bold: isMe)).lineLimit(1)
            Spacer()
            Text("\(entry.rating)")
                .font(KFont.mono(13, bold: true))
                .foregroundStyle(isMe ? accent : Theme.text)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(isMe ? accent.opacity(0.12) : Theme.surface)
        .overlay(Rectangle().stroke(isMe ? accent : Theme.border, lineWidth: 1))
    }
}

/// Classement général de la ligue : ma place parmi tous les joueurs classés, puis
/// le top 100. Ma place vient d'une requête à part (`myRankedRank`) : hors du top
/// 100, elle ne peut pas se déduire de la liste affichée.
struct RankedLeaderboardView: View {
    @Environment(\.accent) private var accent

    @State private var board: [SupabaseService.RankedLeaderboardEntry] = []
    @State private var me: SupabaseService.MyRankedRank?
    @State private var loading = true

    private var myID: String? { SupabaseService.shared.userID }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("CLASSEMENT GÉNÉRAL").font(KFont.mono(13, bold: true))
                    Spacer()
                }

                myPlaceCard

                if !board.isEmpty {
                    SectionLabel("Top \(board.count)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 6) {
                        ForEach(board) { RankedRow(entry: $0, isMe: $0.user_id == myID) }
                    }
                } else if !loading {
                    Text("Personne n'est encore classé.")
                        .font(KFont.body(12))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }
            .screenPadding()
            .padding(.vertical, 12)
        }
        .screenBackground()
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var myPlaceCard: some View {
        VStack(spacing: 6) {
            SectionLabel("Ta place")
            if let me {
                ScoreText(value: me.rank, size: 40)
                Text("sur \(me.total) joueur\(me.total > 1 ? "s" : "") classé\(me.total > 1 ? "s" : "")")
                    .font(KFont.body(12))
                    .foregroundStyle(Theme.muted)
            } else {
                Text(loading ? "..." : "Joue un match classé pour entrer au classement.")
                    .font(KFont.body(12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .kPanel(18)
    }

    private func load() async {
        loading = true
        await SupabaseService.shared.start()
        board = await SupabaseService.shared.rankedLeaderboard(limit: 100)
        me = await SupabaseService.shared.myRankedRank()
        loading = false
    }
}

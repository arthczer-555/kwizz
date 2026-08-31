import SwiftUI

/// The live ranking shown during a duel (points = questions won). Reads the ordered
/// scoreboard straight from the pure `DuelMatch`.
///
/// In `compact` mode (during play, above the question) it only shows the head of the
/// ranking plus the local player, and counts the rest: with up to 16 players a full
/// list would push the question off the screen.
struct LiveScoreboardView: View {
    let duel: DuelController
    var compact: Bool = false
    /// Lignes affichées en mode compact avant de résumer le reste.
    var compactLimit: Int = 5
    @Environment(\.accent) private var accent

    private var rows: [DuelScore] {
        guard compact else { return duel.match.scoreboard }
        return duel.match.topScores(limit: compactLimit, alwaysInclude: duel.localClientID)
    }

    private var hiddenCount: Int { max(0, duel.match.players.count - rows.count) }

    var body: some View {
        VStack(spacing: compact ? 5 : 8) {
            ForEach(rows) { score in
                row(score)
            }
            if hiddenCount > 0 {
                HStack {
                    Text("+\(hiddenCount) AUTRE\(hiddenCount > 1 ? "S" : "") JOUEUR\(hiddenCount > 1 ? "S" : "")")
                        .font(KFont.mono(9)).tracking(1).foregroundStyle(Theme.muted)
                    Spacer()
                    Text("\(answeredCount)/\(duel.match.players.count) ONT RÉPONDU")
                        .font(KFont.mono(9)).tracking(1).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    /// Combien de joueurs ont déjà répondu à la question en cours.
    private var answeredCount: Int {
        duel.match.scoreboard.filter(\.answeredCurrent).count
    }

    private func row(_ score: DuelScore) -> some View {
        let isLocal = score.player.clientID == duel.localClientID
        return HStack(spacing: 8) {
            // Avec beaucoup de joueurs, le rang situe mieux que l'ordre des lignes,
            // qui peut sauter des places quand le classement est tronqué.
            if duel.match.needsCompactRoster {
                Text("#\(score.rank)")
                    .font(KFont.mono(compact ? 10 : 12, bold: true))
                    .foregroundStyle(score.rank == 1 ? accent : Theme.muted)
                    .frame(width: 26, alignment: .leading)
            }
            Circle()
                .fill(Color(hex: score.player.accentHex ?? Theme.Accent.vert.hex))
                .frame(width: 8, height: 8)
            Text(score.player.pseudo)
                .font(KFont.mono(compact ? 11 : 13, bold: isLocal))
                .foregroundStyle(isLocal ? accent : Theme.text)
                .lineLimit(1)
            if score.answeredCurrent {
                Image(systemName: "checkmark").font(.system(size: 9)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Text("\(score.points) pt")
                .font(KFont.mono(compact ? 12 : 15, bold: true))
                .foregroundStyle(isLocal ? accent : Theme.text)
        }
    }
}

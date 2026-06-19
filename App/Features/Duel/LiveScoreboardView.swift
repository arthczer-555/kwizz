import SwiftUI

/// The live ranking shown during a duel (points = questions won). Reads the ordered
/// scoreboard straight from the pure `DuelMatch`.
struct LiveScoreboardView: View {
    let duel: DuelController
    var compact: Bool = false
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: compact ? 5 : 8) {
            ForEach(duel.match.scoreboard) { score in
                row(score)
            }
        }
    }

    private func row(_ score: DuelScore) -> some View {
        let isLocal = score.player.clientID == duel.localClientID
        return HStack(spacing: 8) {
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

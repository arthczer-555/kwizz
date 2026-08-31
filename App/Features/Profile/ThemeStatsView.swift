import SwiftUI

/// « Score par thème » : le pourcentage de bonnes réponses du joueur, thème par thème.
struct ThemeStatsView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent

    /// Une ligne prête à afficher : la catégorie résolue plus son cumul.
    private struct Row: Identifiable {
        let category: Category
        let stat: ThemeStat
        var id: String { category.id }
    }

    /// Tri par nombre de questions répondues décroissant, et non par précision :
    /// un thème joué 3 fois à 100 % passerait devant un thème joué 200 fois à 80 %,
    /// ce qui donne un classement flatteur mais peu représentatif. À égalité de
    /// volume, la meilleure précision passe devant, puis l'ordre alphabétique.
    private var rows: [Row] {
        store.profile.themeStats
            .compactMap { id, stat -> Row? in
                // « Mélange » n'est jamais porté par une vraie question, mais on
                // s'en protège au cas où une vieille sauvegarde en contiendrait.
                guard id != Category.melange.id, stat.answered > 0,
                      let category = Category.find(id: id) else { return nil }
                return Row(category: category, stat: stat)
            }
            .sorted {
                if $0.stat.answered != $1.stat.answered { return $0.stat.answered > $1.stat.answered }
                if $0.stat.accuracy != $1.stat.accuracy { return $0.stat.accuracy > $1.stat.accuracy }
                return $0.category.name < $1.category.name
            }
    }

    private var totalAnswered: Int { rows.reduce(0) { $0 + $1.stat.answered } }
    private var totalCorrect: Int { rows.reduce(0) { $0 + $1.stat.correct } }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: "Score par thème")

            if rows.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        summary
                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                                if idx > 0 { Divider().overlay(Theme.border) }
                                themeRow(row)
                            }
                        }
                    }
                    .padding(.top, 14)
                }
            }
        }
        .screenPadding()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .screenBackground()
    }

    // MARK: - Morceaux

    @ViewBuilder private var summary: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                SectionLabel("\(rows.count) thème\(rows.count > 1 ? "s" : "") joué\(rows.count > 1 ? "s" : "")")
                Text("\(totalCorrect)/\(totalAnswered) bonnes réponses")
                    .font(KFont.body(10))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text("\(percent(totalAnswered > 0 ? Double(totalCorrect) / Double(totalAnswered) : 0))%")
                .font(KFont.mono(22))
                .foregroundStyle(accent)
        }
        .kPanel()
    }

    @ViewBuilder private func themeRow(_ row: Row) -> some View {
        let color = Color(hex: row.category.colorHex)
        VStack(spacing: 7) {
            HStack(spacing: 9) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Image(systemName: row.category.symbol)
                    .font(.system(size: 12))
                    .frame(width: 18)
                    .foregroundStyle(Theme.muted)
                Text(row.category.name)
                    .font(KFont.body(14))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                Text("\(percent(row.stat.accuracy))%")
                    .font(KFont.mono(15, bold: true))
                    .foregroundStyle(accuracyColor(row.stat.accuracy))
            }
            ThemeAccuracyBar(fraction: row.stat.accuracy, color: color)
            HStack {
                SectionLabel("\(row.stat.correct)/\(row.stat.answered) questions")
                Spacer()
            }
        }
        .padding(.vertical, 13)
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "chart.bar")
                .font(.system(size: 26))
                .foregroundStyle(Theme.muted)
            Text("Aucun thème joué")
                .font(KFont.mono(13, bold: true))
                .foregroundStyle(Theme.text)
            Text("Termine une manche pour voir ton pourcentage de bonnes réponses thème par thème.")
                .font(KFont.body(12))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func percent(_ fraction: Double) -> Int {
        Int((fraction * 100).rounded())
    }

    /// Vert (accent) quand le thème est maîtrisé, neutre au milieu, rouge en dessous
    /// de 40 % pour repérer d'un coup d'œil les thèmes à retravailler.
    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.6 { return accent }
        if accuracy >= 0.4 { return Theme.text }
        return Theme.bad
    }
}

/// Même géométrie que `XPBar`, mais peinte à la couleur du thème.
private struct ThemeAccuracyBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(hex: "#0c0c0c"))
                Rectangle()
                    .fill(color)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 7)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        ThemeStatsView()
    }
    .environment(PlayerStore())
    .environment(\.accent, Theme.Accent.vert.color)
}

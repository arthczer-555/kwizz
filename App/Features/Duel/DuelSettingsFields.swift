import SwiftUI

/// Les champs de configuration d'une partie (mise, cagnotte, règle de score, thème),
/// utilisés par `DuelSetupView`. Ils sont volontairement ignorants du
/// `DuelController` : à ce stade aucun salon n'existe encore, et une fois la
/// partie créée ces réglages sont figés, le salon se contente de les refléter.

// MARK: - Mise

/// Le champ « mise par joueur » : montant courant, curseur exponentiel et bornes.
/// Il ne connaît que des pièces, pas de `DuelController`, pour servir aussi bien
/// avant la création du salon qu'à l'intérieur.
struct StakeField: View {
    /// Mise actuellement retenue.
    let stake: Int
    /// Bout droit du curseur : le porte-monnaie de l'hôte.
    let maxStake: Int
    /// Position affichée (permet à l'appelant de suivre un glissement en cours).
    let position: Double
    /// `committed` faux pendant le glissement, vrai au relâchement.
    let onChange: (Double, Bool) -> Void

    private var broke: Bool { maxStake <= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Mise par joueur")
                Spacer()
                if stake == 0 {
                    Text("AMICALE").font(KFont.mono(11, bold: true)).tracking(1)
                        .foregroundStyle(Theme.muted)
                } else {
                    CoinLabel(amount: stake)
                }
            }

            // Le curseur est rendu même à zéro pièce : le masquer donnait un écran
            // où la mise semblait ne pas exister du tout.
            StakeSlider(position: position, onChange: onChange)
                .disabled(broke)
                .opacity(broke ? 0.3 : 1)

            HStack {
                Text("AMICALE").font(KFont.mono(9)).tracking(1).foregroundStyle(Theme.muted)
                Spacer()
                Text(broke ? "0 PIÈCE" : "TOUT MISER · \(maxStake)")
                    .font(KFont.mono(9)).tracking(1).foregroundStyle(Theme.muted)
            }

            if broke {
                Text("Tu n'as pas encore de pièces à miser : joue une partie pour en gagner, puis reviens fixer une mise.")
                    .font(KFont.mono(10)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Longueur de la manche

/// Le choix du nombre de questions. Rendu en quatre cases côte à côte, chacune
/// avec sa durée approximative : « 21 » ne dit pas de lui-même qu'on part pour
/// sept minutes à quatre joueurs, et c'est la vraie question que se pose l'hôte.
struct QuestionCountField: View {
    let questionCount: Int
    let onSelect: (Int) -> Void
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Nombre de questions")
                Spacer()
                Text("\(questionCount) QUESTIONS")
                    .font(KFont.mono(11, bold: true)).tracking(1)
                    .foregroundStyle(accent)
            }

            HStack(spacing: 0) {
                ForEach(Array(DuelSettings.questionCountOptions.enumerated()), id: \.element) { idx, count in
                    if idx > 0 { Rectangle().fill(Theme.border).frame(width: 1) }
                    Button { onSelect(count) } label: {
                        QuestionCountCell(count: count, selected: count == questionCount)
                    }
                    .buttonStyle(.plain)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))

            Text("Environ \(DuelSettings.estimatedMinutes(questionCount: questionCount)) minutes de jeu, révélations comprises.")
                .font(KFont.mono(10))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QuestionCountCell: View {
    let count: Int
    let selected: Bool
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(KFont.pixel(22))
                .foregroundStyle(selected ? Theme.bg : Theme.text)
            Text("~\(DuelSettings.estimatedMinutes(questionCount: count)) MIN")
                .font(KFont.mono(8)).tracking(1)
                .foregroundStyle(selected ? Theme.bg.opacity(0.7) : Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(selected ? accent : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Règle de score

/// Le choix de la règle de score : une ligne sélectionnable par mode, avec son
/// explication, pour qu'on sache ce qu'on choisit sans l'avoir essayé.
struct ScoringField: View {
    let scoring: DuelScoring
    let onSelect: (DuelScoring) -> Void
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Comment on marque")

            VStack(spacing: 0) {
                ForEach(Array(DuelScoring.allCases.enumerated()), id: \.element) { idx, mode in
                    if idx > 0 { Divider().overlay(Theme.border) }
                    Button { onSelect(mode) } label: {
                        ScoringRow(mode: mode, selected: mode == scoring)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScoringRow: View {
    let mode: DuelScoring
    let selected: Bool
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Case carrée pleine quand choisie : cohérent avec le reste pixel,
            // là où un Toggle système jurerait.
            Rectangle()
                .fill(selected ? accent : Color.clear)
                .frame(width: 11, height: 11)
                .overlay(Rectangle().stroke(selected ? accent : Theme.border, lineWidth: 1))
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.title)
                    .font(KFont.mono(13, bold: selected))
                    .foregroundStyle(selected ? accent : Theme.text)
                Text(mode.detail)
                    .font(KFont.body(12))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Thème

/// Le choix du thème des questions : « Tout » (toutes les catégories) ou l'une
/// des 13. Un seul bouton qui ouvre la liste, plutôt que les quatorze options à
/// plat : déroulées, elles poussaient la mise et la règle de score hors de l'écran.
struct ThemeField: View {
    let categoryID: String
    let onSelect: (String) -> Void
    @Environment(\.accent) private var accent
    @State private var picking = false

    private var category: Category { Category.find(id: categoryID) ?? .melange }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Thème")

            Button { picking = true } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: category.colorHex))
                        .frame(width: 9, height: 9)
                    Image(systemName: category.symbol)
                        .frame(width: 20)
                        .foregroundStyle(Theme.muted)
                    Text(DuelSettings.themeName(of: categoryID))
                        .font(KFont.mono(15, bold: true))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text("CHOISIR")
                        .font(KFont.mono(9)).tracking(1)
                        .foregroundStyle(Theme.muted)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 14).padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(categoryID == Category.melange.id
                 ? "Les questions sont tirées dans tous les thèmes."
                 : "Toutes les questions de la manche viennent de ce thème.")
                .font(KFont.mono(10))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $picking) {
            ThemePickerSheet(categoryID: categoryID) { id in
                onSelect(id)
                picking = false
            }
        }
    }
}

/// La liste des thèmes, en feuille. « Tout » en tête : c'est le réglage par
/// défaut et le plus joué, il ne se cherche pas au milieu des catégories.
private struct ThemePickerSheet: View {
    let categoryID: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var options: [Category] { [.melange] + Category.all }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("THÈME").font(KFont.mono(13, bold: true)).tracking(1)
                    .foregroundStyle(Theme.text)
                Spacer()
                Button { dismiss() } label: {
                    Text("FERMER")
                        .font(KFont.mono(10)).tracking(1).foregroundStyle(Theme.muted)
                        .padding(.vertical, 7).padding(.horizontal, 10)
                        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .screenPadding()
            .padding(.vertical, 16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { idx, category in
                        if idx > 0 { Divider().overlay(Theme.border) }
                        Button { onSelect(category.id) } label: {
                            ThemeRow(category: category, selected: category.id == categoryID)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                .screenPadding()
                .padding(.bottom, 24)
            }
        }
        .screenBackground()
    }
}

private struct ThemeRow: View {
    let category: Category
    let selected: Bool
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: category.colorHex))
                .frame(width: 8, height: 8)
            Image(systemName: category.symbol)
                .frame(width: 22)
                .foregroundStyle(selected ? accent : Theme.muted)
            Text(DuelSettings.themeName(of: category.id))
                .font(KFont.body(14))
                .foregroundStyle(selected ? accent : Theme.text)
            Spacer(minLength: 6)
            if selected {
                // Carré plein plutôt qu'une coche système : même repère de
                // sélection que la règle de score.
                Rectangle()
                    .fill(accent)
                    .frame(width: 11, height: 11)
            }
        }
        .padding(.vertical, 13).padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Curseur

/// Le curseur de mise. Il rend une position brute (0...1) : c'est `DuelWager` qui
/// la convertit en pièces le long d'une courbe exponentielle, de sorte que la
/// poignée avance pièce par pièce à gauche et par paquets à droite.
///
/// `onChange` est appelé en continu pendant le glissement (`committed` faux, pour
/// l'aperçu local) puis une fois au relâchement (`committed` vrai) : dans un salon
/// déjà ouvert, la mise n'est diffusée qu'à ce moment-là, pas à chaque pixel.
struct StakeSlider: View {
    let position: Double
    let onChange: (Double, Bool) -> Void
    @Environment(\.accent) private var accent

    private let handleWidth: CGFloat = 14
    private let handleHeight: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let travel = max(geo.size.width - handleWidth, 1)
            let x = travel * min(max(position, 0), 1)
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.border)
                    .frame(height: 2)
                Rectangle().fill(accent)
                    .frame(width: x + handleWidth / 2, height: 2)
                notches(travel: travel)
                Rectangle().fill(accent)
                    .frame(width: handleWidth, height: handleHeight)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in onChange(fraction(value.location.x, travel), false) }
                    .onEnded { value in onChange(fraction(value.location.x, travel), true) }
            )
        }
        .frame(height: handleHeight + 8)
    }

    /// Repères réguliers le long du rail : ils situent la poignée sans prétendre
    /// indiquer des montants (la courbe n'est pas linéaire).
    private func notches(travel: CGFloat) -> some View {
        ForEach(1..<10) { i in
            Rectangle().fill(Theme.border)
                .frame(width: 1, height: 6)
                .offset(x: handleWidth / 2 + travel * CGFloat(i) / 10)
        }
    }

    /// Position du doigt -> fraction du rail, en visant le centre de la poignée.
    private func fraction(_ locationX: CGFloat, _ travel: CGFloat) -> Double {
        Double(min(max((locationX - handleWidth / 2) / travel, 0), 1))
    }
}

// MARK: - Cagnotte

/// Le bandeau « cagnotte » : ce que la table met en jeu et ce que le gagnant rafle.
///
/// `playerCount` est nil tant que le salon n'est pas ouvert : la cagnotte dépend
/// alors du nombre d'arrivants, donc on annonce un plancher et une projection
/// plutôt qu'un montant unique qui serait faux à la première arrivée.
struct PotSummary: View {
    let stake: Int
    let playerCount: Int?
    @Environment(\.accent) private var accent

    /// Cagnotte minimale garantie si la partie se lance au minimum de joueurs.
    private var floorPot: Int { stake * DuelMatch.minPlayers }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("Cagnotte")
                Spacer()
                if stake <= 0 {
                    Text("—").font(KFont.mono(13)).foregroundStyle(Theme.muted)
                } else if let playerCount, playerCount >= DuelMatch.minPlayers {
                    CoinLabel(amount: stake * playerCount)
                } else {
                    HStack(spacing: 5) {
                        Text("DÈS").font(KFont.mono(9)).tracking(1).foregroundStyle(Theme.muted)
                        CoinLabel(amount: floorPot)
                    }
                }
            }

            Text(detail)
                .font(KFont.mono(11))
                .foregroundStyle(stake > 0 ? Theme.text : Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            // Salon pas encore ouvert : montrer où la cagnotte peut monter répond
            // à la vraie question de l'hôte, « combien se joue cette partie ».
            if stake > 0, playerCount == nil {
                projection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var projection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().overlay(Theme.border)
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(steps, id: \.self) { count in
                    HStack(spacing: 5) {
                        Text("\(count)J").font(KFont.mono(9)).tracking(1).foregroundStyle(Theme.muted)
                        Text("\(stake * count)").font(KFont.mono(11, bold: true)).foregroundStyle(accent)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                }
            }
        }
    }

    /// Paliers de salle projetés, bornés au plafond de joueurs.
    private var steps: [Int] {
        [2, 4, 8, 16].filter { $0 >= DuelMatch.minPlayers && $0 <= DuelMatch.maxPlayers }
    }

    private var detail: String {
        guard stake > 0 else { return "Partie amicale : aucune pièce en jeu." }
        guard let playerCount, playerCount >= DuelMatch.minPlayers else {
            return "Chacun mise \(stake) pièces. La cagnotte vaut \(stake) × le nombre de joueurs, et le gagnant rafle tout."
        }
        let net = stake * playerCount - stake
        return "Chacun mise \(stake) pièces. Cagnotte : \(stake * playerCount) pièces (\(playerCount) × \(stake)). Le gagnant rafle tout, soit +\(net) net."
    }
}

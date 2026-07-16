import SwiftUI

/// Réservation d'un pseudo, partagée par l'onboarding et le profil : même
/// validation, mêmes messages. C'est le serveur qui tranche l'unicité (RPC
/// `claim_pseudo`) : le client ne peut pas la tester lui-même, RLS ne l'autorise
/// à lire que son propre profil.
@MainActor
@Observable
final class PseudoClaim {
    var text: String
    private(set) var error: String?
    private(set) var isBusy = false

    init(text: String = "") { self.text = text }

    var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isLengthValid: Bool { (2...24).contains(trimmed.count) }

    func clearError() { error = nil }

    /// Réserve le pseudo puis l'écrit en local. `false` => `error` dit pourquoi.
    /// Hors ligne, on accepte quand même : le jeu se joue sans réseau. En cas de
    /// conflit à la sync suivante, c'est le pseudo du serveur qui fait foi.
    func submit(into store: PlayerStore) async -> Bool {
        guard !isBusy else { return false }
        guard isLengthValid else {
            error = "Entre 2 et 24 caractères."
            return false
        }

        isBusy = true
        defer { isBusy = false }

        let name = trimmed
        switch await SupabaseService.shared.claimPseudo(name) {
        case .ok, .unavailable:
            store.setPseudo(name)
            error = nil
            return true
        case .taken:
            error = "\"\(name)\" est déjà pris."
            return false
        case .invalid:
            error = "Entre 2 et 24 caractères."
            return false
        }
    }
}

/// Champ pseudo + message d'erreur, commun à l'onboarding et au profil.
struct PseudoField: View {
    @Environment(\.accent) private var accent
    @Bindable var claim: PseudoClaim
    var onSubmit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            SectionLabel("Pseudo")
            TextField("Ton pseudo", text: $claim.text)
                .font(KFont.mono(18))
                .foregroundStyle(Theme.text)
                .tint(accent)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .onChange(of: claim.text) { claim.clearError() }

            if let error = claim.error {
                Text(error)
                    .font(KFont.body(11))
                    .foregroundStyle(Theme.bad)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Renommage depuis le profil.
struct PseudoEditSheet: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var claim: PseudoClaim

    init(current: String) {
        _claim = State(initialValue: PseudoClaim(text: current))
    }

    var body: some View {
        VStack(spacing: Space.lg) {
            HStack {
                Text("CHANGER DE PSEUDO").font(KFont.mono(13, bold: true))
                Spacer()
            }

            PseudoField(claim: claim) { submit() }
                .kPanel()

            PixelButton(title: claim.isBusy ? "..." : "Valider") { submit() }
                .disabled(claim.isBusy || !claim.isLengthValid)

            Spacer()
        }
        .padding(Space.lg)
        .screenBackground()
    }

    private func submit() {
        Task { if await claim.submit(into: store) { dismiss() } }
    }
}

import SwiftUI

struct AchievementsView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent

    private func isUnlocked(_ a: Achievement) -> Bool {
        store.profile.unlockedAchievementIDs.contains(a.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: "Succès")
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Achievement.catalog) { a in
                        let done = isUnlocked(a)
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Theme.surface)
                                .overlay(Rectangle().stroke(done ? accent : Theme.border, lineWidth: 1))
                                .frame(width: 40, height: 40)
                                .opacity(done ? 1 : 0.4)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(a.title).font(KFont.body(14))
                                SectionLabel(a.detail)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 5) {
                                rewardLabel(a.reward)
                                Image(systemName: done ? "checkmark" : "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(done ? accent : Theme.muted)
                            }
                        }
                        .padding(.vertical, 13)
                        .opacity(done ? 1 : 0.6)
                        Divider().overlay(Theme.border)
                    }
                }
            }
        }
        .screenPadding()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .screenBackground()
    }

    @ViewBuilder private func rewardLabel(_ reward: AchievementReward) -> some View {
        HStack(spacing: 8) {
            if reward.coins > 0 { CoinLabel(amount: reward.coins) }
            if reward.chests > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "shippingbox.fill").font(.system(size: 10)).foregroundStyle(accent)
                    Text("x\(reward.chests)").font(KFont.mono(12, bold: true)).foregroundStyle(accent)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AchievementsView()
    }
    .environment(PlayerStore())
    .environment(\.accent, Theme.Accent.vert.color)
}

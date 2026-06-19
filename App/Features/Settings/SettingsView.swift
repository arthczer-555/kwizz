import SwiftUI

struct SettingsView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: "Réglages")

            ScrollView {
                VStack(spacing: 0) {
                    toggleRow("Son", store.profile.soundOn) { store.toggleSound() }
                    Divider().overlay(Theme.border)
                    toggleRow("Musique", store.profile.musicOn) { store.toggleMusic() }
                    Divider().overlay(Theme.border)
                    toggleRow("Notifications", store.profile.notificationsOn) { store.toggleNotifications() }
                    Divider().overlay(Theme.border)

                    HStack {
                        Text("Accent").font(KFont.body(14))
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(Theme.Accent.allCases) { a in
                                Button {
                                    store.setAccent(a)
                                } label: {
                                    Circle()
                                        .fill(a.color)
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Circle().stroke(a == store.accent ? Theme.text : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    Divider().overlay(Theme.border)

                    HStack {
                        Text("Langue").font(KFont.body(14))
                        Spacer()
                        Text("FR").font(KFont.mono(12)).foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 16)
                    Divider().overlay(Theme.border)

                    toggleRow("Mode admin", store.adminEnabled) { store.toggleAdmin() }

                    if store.adminEnabled {
                        Divider().overlay(Theme.border)
                        NavigationLink(value: Route.admin) {
                            HStack {
                                Text("Console admin").font(KFont.body(14)).foregroundStyle(Theme.text)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.muted)
                            }
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Kwizz v0.1")
                    .font(KFont.body(11))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 16)
            }
        }
        .screenPadding()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .screenBackground()
    }

    @ViewBuilder
    private func toggleRow(_ title: String, _ value: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(KFont.body(14)).foregroundStyle(Theme.text)
                Spacer()
                Text(value ? "ON" : "OFF")
                    .font(KFont.mono(9))
                    .tracking(1)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 9)
                    .overlay(Rectangle().stroke(value ? accent : Theme.border, lineWidth: 1))
                    .foregroundStyle(value ? accent : Theme.muted)
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(PlayerStore())
            .environment(\.accent, Theme.Accent.vert.color)
    }
}

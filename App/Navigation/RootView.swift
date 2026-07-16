import SwiftUI
import UIKit

struct RootView: View {
    @State private var store: PlayerStore
    @State private var router: Router

    init() {
        let store = PlayerStore()
        _store = State(initialValue: store)
        _router = State(initialValue: Router(store: store))
        TabBarStyle.apply()
    }

    var body: some View {
        content
            .foregroundStyle(Theme.text)
            .environment(store)
            .environment(router)
            .environment(\.accent, store.accentColor)
            .tint(store.accentColor)
            .preferredColorScheme(.dark)
            // Phase 0 (ligue) : établit la session anonyme et pousse le profil.
            // No-op tant que Supabase n'est pas configuré -> l'app reste hors-ligne.
            .task {
                await SupabaseService.shared.start()
                await SupabaseService.shared.syncProfile(store.profile)
                // Renvoie tout défi terminé qui n'a pas pu partir lors d'une session
                // précédente (hors ligne / raté réseau), pour ne perdre aucun score.
                await SupabaseService.shared.flushPendingDaily()
            }
            .onChange(of: store.profile.gamesPlayed) {
                Task { await SupabaseService.shared.syncProfile(store.profile) }
            }
            .onChange(of: store.profile.pseudo) {
                Task { await SupabaseService.shared.syncProfile(store.profile) }
            }
            .fullScreenCover(item: Bindable(router).activeGame) { game in
                GamePlayView(game: game)
                    .foregroundStyle(Theme.text)
                    .environment(store)
                    .environment(router)
                    .environment(\.accent, store.accentColor)
                    .tint(store.accentColor)
                    .preferredColorScheme(.dark)
            }
    }

    @ViewBuilder private var content: some View {
        if store.hasOnboarded {
            tabs
        } else {
            OnboardingView()
        }
    }

    /// Tab selection that resets the "Jouer" stack to its root whenever that tab
    /// is selected, including re-tapping it while already active. This guarantees
    /// "Jouer" always returns to mode selection, wherever the player was before.
    private var tabSelection: Binding<Router.Tab> {
        Binding(
            get: { router.tab },
            set: { newTab in
                if newTab == .play {
                    router.goToPlay()
                } else {
                    router.tab = newTab
                }
            }
        )
    }

    private var tabs: some View {
        TabView(selection: tabSelection) {
            NavigationStack { HomeView().withRoutes() }
                .tag(Router.Tab.home)
                .tabItem { Label("Accueil", systemImage: "house") }
            NavigationStack(path: Bindable(router).playPath) { ModeSelectView().withRoutes() }
                .tag(Router.Tab.play)
                .tabItem { Label("Jouer", systemImage: "gamecontroller") }
            NavigationStack { ShopView().withRoutes() }
                .tag(Router.Tab.shop)
                .tabItem { Label("Shop", systemImage: "bag") }
            NavigationStack { RankedHubView().withRoutes() }
                .tag(Router.Tab.rank)
                .tabItem { Label("Rang", systemImage: "trophy") }
            NavigationStack { ProfileView().withRoutes() }
                .tag(Router.Tab.profile)
                .tabItem { Label("Profil", systemImage: "person") }
        }
    }
}

/// Themes the system tab bar to match the arcade-minimal look: a near-black
/// background, a hairline top border, a small mono font, and muted icons.
/// The selected colour is left to SwiftUI's `.tint(accent)` so it follows the
/// player's accent choice.
enum TabBarStyle {
    static func apply() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.bg)
        appearance.shadowColor = UIColor(Theme.border)

        let muted = UIColor(Theme.muted)
        let font = UIFont(name: "SpaceMono-Regular", size: 10)
            ?? .systemFont(ofSize: 10, weight: .medium)

        for layout in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ] {
            layout.normal.iconColor = muted
            layout.normal.titleTextAttributes = [.foregroundColor: muted, .font: font]
            // Selected colour comes from the tint; only pin the font here.
            layout.selected.titleTextAttributes = [.font: font]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

extension View {
    /// Registers the shared push destinations on a navigation stack.
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            RouteView(route: route)
        }
    }
}

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .modeSelect: ModeSelectView()
        case .category(let mode): CategorySelectView(mode: mode)
        case .subcategory(let mode, let category): SubcategorySelectView(mode: mode, category: category)
        case .difficulty(let mode, let category, let subcategory):
            DifficultySelectView(mode: mode, category: category, subcategory: subcategory)
        case .defiIntro: DefiIntroView()
        case .dailyWheel: DailyWheelView()
        case .chestOpen: ChestOpenView()
        case .shopItem(let id): ItemDetailView(itemID: id)
        case .avatar: AvatarView()
        case .achievements: AchievementsView()
        case .settings: SettingsView()
        case .admin: AdminView()
        case .duelEntry: DuelEntryView()
        case .rankedLeaderboard: RankedLeaderboardView()
        }
    }
}

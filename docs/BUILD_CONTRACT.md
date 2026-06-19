# Kwizz - Build contract (READ FULLY before writing any view)

You are writing **one SwiftUI screen** for the Kwizz iOS app. Follow this contract
exactly so the file compiles against the existing code. The app target compiles
`Sources/KwizzCore` + `App/` into a **single module**.

## Hard rules
- `import SwiftUI` only. **NEVER** `import KwizzCore` (same module). Add `import Foundation` only if needed.
- Use the existing design-system components and `Theme`/`KFont` below. Do **not** invent new colors; pull from `Theme` and `@Environment(\.accent)`.
- Arcade-minimal look (see `mockups/prototype.html`): near-black background, mono/pixel type, **sharp corners** (no cornerRadius), thin 1px `Theme.border` strokes, a single accent used sparingly.
- One screen per file, exactly at the path given in your task. Provide a `#Preview` at the end.
- Access shared state with `@Environment(PlayerStore.self) private var store` and `@Environment(Router.self) private var router` and `@Environment(\.accent) private var accent`.
- Do not redeclare any type that already exists (Theme, components, Core types, Router, Route, PlayerStore...).

## Design-system API (already implemented, do not redefine)
- `Theme.bg, bg2, surface, surface2, border, text, muted, faint, bad, accentInk` (all `Color`).
- `Theme.Accent` enum `{ vert, ambre, cyan, mono }` with `.color: Color`, `.title: String`, `.allCases`.
- `KFont.pixel(_ size: CGFloat) -> Font` (logo + big scores only), `KFont.mono(_ size: CGFloat, bold: Bool = false) -> Font`, `KFont.body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font`.
- `Space.xs/sm/md/lg/xl` (CGFloat).
- `@Environment(\.accent) -> Color` (current accent color).
- `Color(hex: "#rrggbb")` initializer exists.
- Components (all are `View`s unless noted):
  - `PixelButton(title: String, style: PixelButton.Style = .filled, fullWidth: Bool = true, action: () -> Void)` ; `Style` is `.filled` or `.ghost`. Usage: `PixelButton(title: "Jouer") { ... }`.
  - `KTag(title: String, selected: Bool = false)` — a non-interactive chip. Wrap in `Button { } label: { KTag(...) }.buttonStyle(.plain)` to make it tappable.
  - `SectionLabel(_ text: String)` — small uppercased muted mono label.
  - `CoinLabel(amount: Int, color: Color? = nil)` — ring + number.
  - `ScoreText(value: Int, size: CGFloat = 50)` — big pixel accent number.
  - `XPBar(fraction: Double)` — thin progress bar (height 7).
  - `TopBar(coins: Int, level: Int, onGear: (() -> Void)? = nil)` — top row for tab-root screens.
  - `BackHeader(title: String)` — back row for **pushed** screens (calls dismiss).
  - `KwizzLogo(size: CGFloat = 34)`.
  - `NavButton(title: String, style: PixelButton.Style = .filled, route: Route)` — a `PixelButton`-styled `NavigationLink`. Use this for forward navigation, e.g. `NavButton(title: "Jouer", route: .modeSelect)`.
  - `MannequinView(scale: CGFloat = 1.0, showSpot: Bool = true, ringColor: Color? = nil)` — the placeholder avatar (silhouette + ground shadow). Use this wherever an avatar is shown.
  - View modifiers: `.kPanel(_ padding: CGFloat = 14)` (surface + border) and `.screenBackground()` (fills + Theme.bg). Put `.screenBackground()` on the outermost container.

## Core types (same module, no import)
- `Category`: `.all: [Category]`, `.melange`, `.find(id: String) -> Category?`. Props: `id, name, colorHex (String), symbol (SF Symbol String), subcategories: [Subcategory]`. `Subcategory { id, name }`. Both `Identifiable, Hashable`.
- `GameMode` (`.allCases`): `classique, contreLaMontre, survie, marathon, libre, duel, defi`. Props: `title, subtitle, symbol, questionCount: Int?, hasPerQuestionTimer, endsOnFirstWrong, tracksRecord`.
- `Difficulty` (`.allCases`): `facile, normal, difficile`. Props: `title, timePerQuestion: Double, coinMultiplier: Double, xpPerCorrect: Int, gainLabel: String`.
- `AvatarSlot` (`.allCases`): `tete, cheveux, lunettes, haut, fond, cadre` with `.title`. `Rarity`: `commun, rare, epique, legendaire` with `.title, .colorHex, .order`.
- `AvatarItem`: `.catalog: [AvatarItem]`, `.item(id:) -> AvatarItem?`, `.items(slot:) -> [AvatarItem]`. Props: `id, name, slot, rarity, price: Int, unlockLevel: Int?, isLevelLocked: Bool`.
- `LevelTable`: `.title(level: Int) -> String`, `.maxLevel`, `.progress(totalXP: Int) -> LevelProgress`. `LevelProgress { level, title, xpIntoLevel, xpForNextLevel, fraction, isMax }`.
- `PlayerProfile` props you may read: `pseudo, totalXP, coins, ownedItemIDs (Set<String>), equipped ([String:String]), gamesPlayed, totalCorrect, totalAnswered, bestStreakEver, dailyStreak`. Derived: `level: Int, levelProgress: LevelProgress, title: String, accuracy: Double (0...1), bestScoreOverall: Int`.

## PlayerStore (`@Environment(PlayerStore.self) private var store`)
`store.profile` (PlayerProfile), `store.bank`, `store.accent: Theme.Accent`, `store.accentColor: Color`,
`store.today() -> Int`, `store.dailyAvailable: Bool`,
`store.completeOnboarding(pseudo: String)`,
`store.isOwned(_ item) -> Bool`, `store.isUnlocked(_ item) -> Bool`, `store.buy(_ item) -> Bool` (discardable), `store.equip(_ item)`, `store.equippedItem(slot:) -> AvatarItem?`,
`store.setAccent(_ accent: Theme.Accent)`, `store.toggleSound()`, `store.toggleMusic()`, `store.toggleNotifications()`.
Mutate via these methods (the store persists). Read `store.profile.xxx` for display.

## Router (`@Environment(Router.self) private var router`)
- `router.tab` (`Router.Tab`: `.home/.play/.shop/.rank/.profile`), `router.startGame(mode:category:subcategory:difficulty:)`, `router.endGame()`, `router.goHome()`.
- `Route` enum cases for `NavigationLink(value:)`: `.modeSelect`, `.category(GameMode)`, `.subcategory(GameMode, Category)`, `.difficulty(GameMode, Category?, Subcategory?)`, `.defiIntro`, `.shopItem(String)`, `.avatar`, `.achievements`, `.settings`.

## Navigation patterns
- **Tab-root screens** (Home, ModeSelect, Shop, Leaderboard, Profile): no BackHeader. They already sit in a `NavigationStack`. Forward navigation with `NavigationLink(value: Route.xxx) { rowLabel }.buttonStyle(.plain)`.
- **Pushed screens** (anything reached via a Route): begin the body with `BackHeader(title: "...")`, and add to the outermost view: `.navigationBarBackButtonHidden(true)` and `.toolbar(.hidden, for: .navigationBar)`.
- **To start a game**: call `router.startGame(...)`. Do NOT navigate to the game; a full-screen cover handles it.
- Wrap scrollable content in `ScrollView { ... }`. Always apply `.screenBackground()` to the outer container.

## Reference
Open `mockups/prototype.html` and match the corresponding screen's layout and spirit (it is the source of truth for visual design). Keep it clean and minimal.

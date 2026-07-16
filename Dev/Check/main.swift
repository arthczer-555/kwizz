import Foundation
import KwizzCore

// A dependency-free verification runner for the pure game logic.
// Mirrors Tests/KwizzCoreTests (Swift Testing) so the invariants can be checked
// from a plain Swift toolchain: `swift run KwizzCoreCheck`.

var total = 0
var failures = 0

@MainActor func check(_ cond: Bool, _ msg: @autoclosure () -> String) {
    total += 1
    if !cond {
        failures += 1
        print("  FAIL: \(msg())")
    }
}

@MainActor func eq<T: Equatable>(_ a: T, _ b: T, _ label: String) {
    check(a == b, "\(label): got \(a), expected \(b)")
}

func q(_ id: String, cat: String = "histoire", diff: Difficulty = .normal, correct: Int = 0) -> Question {
    Question(id: id, categoryID: cat, subcategoryID: nil, difficulty: diff,
             text: "Q \(id) ?", answers: ["A", "B", "C", "D"], correctIndex: correct)
}

// MARK: Level table
eq(LevelTable.xpToNext.count, 19, "xpToNext count")
eq(LevelTable.cumulative.count, 20, "cumulative count")
eq(LevelTable.totalToMax, 238_850, "totalToMax")
eq(LevelTable.title(level: 1), "Niveau 1", "first title")
eq(LevelTable.title(level: 20), "Niveau 20", "last title")
check((1..<LevelTable.cumulative.count).allSatisfy { LevelTable.cumulative[$0] > LevelTable.cumulative[$0 - 1] }, "cumulative strictly increasing")
eq(LevelTable.level(totalXP: 0), 1, "level @0")
eq(LevelTable.level(totalXP: 149), 1, "level @149")
eq(LevelTable.level(totalXP: 150), 2, "level @150")
eq(LevelTable.level(totalXP: 449), 2, "level @449")
eq(LevelTable.level(totalXP: 450), 3, "level @450")
eq(LevelTable.level(totalXP: 238_849), 19, "level @238849")
eq(LevelTable.level(totalXP: 238_850), 20, "level @238850")
eq(LevelTable.level(totalXP: 9_000_000), 20, "level @max")
eq(LevelTable.level(totalXP: -50), 1, "level @negative")
let prog = LevelTable.progress(totalXP: 150)
eq(prog.level, 2, "progress level"); eq(prog.xpForNextLevel, 300, "progress need"); check(abs(prog.fraction) < 0.0001, "progress fraction 0")
check(LevelTable.progress(totalXP: 500_000).isMax, "progress isMax")
eq(LevelTable.reward(reachingLevel: 2).coins, 20, "reward L2 coins")
check(LevelTable.reward(reachingLevel: 2).itemRarity == nil, "reward L2 no item")
check(LevelTable.reward(reachingLevel: 5).itemRarity == .commun, "reward L5 item")
check(LevelTable.reward(reachingLevel: 20).itemRarity == .legendaire, "reward L20 item")

// MARK: Scoring
eq(Scoring.questionScore(correct: true, remainingFraction: 1.0, hasSpeedBonus: true), 200, "score fast")
eq(Scoring.questionScore(correct: true, remainingFraction: 0.0, hasSpeedBonus: true), 100, "score slow")
eq(Scoring.questionScore(correct: true, remainingFraction: 0.5, hasSpeedBonus: true), 150, "score half")
eq(Scoring.questionScore(correct: false, remainingFraction: 1.0, hasSpeedBonus: true), 0, "score wrong")
eq(Scoring.questionScore(correct: true, remainingFraction: 1.0, hasSpeedBonus: false), 100, "score no-bonus mode")
eq(Scoring.maxScore(questionCount: 15), 3000, "max score 15")
eq(Scoring.maxScore(questionCount: 30, hasSpeedBonus: false), 3000, "max score 30 no bonus")

// MARK: Economy
func ein(_ mode: GameMode, _ diff: Difficulty = .normal, correct: Int = 10, total: Int = 10, fast: Int = 0,
         perfect: Bool = false, streak: Int = 0, frac: Double = 0, duel: Bool? = nil) -> Economy.Input {
    Economy.Input(mode: mode, coinMultiplier: diff.coinMultiplier, correctCount: correct, total: total,
                  perfect: perfect, bestStreak: streak, fastCount: fast, scoreFraction: frac, duelWon: duel)
}
eq(Economy.coins(ein(.entrainement, .facile, correct: 55)), 5, "entrainement training")
eq(Economy.coins(ein(.classique, .normal, correct: 20)), 30, "classique normal")
eq(Economy.coins(ein(.contreLaMontre, .normal, correct: 14)), 21, "clm normal")
eq(Economy.coins(ein(.survie, .facile, correct: 12, streak: 12)), 14, "survie")
eq(Economy.coins(ein(.duel, duel: true)), 15, "duel win")
eq(Economy.coins(ein(.duel, duel: false)), -15, "duel loss")
eq(Economy.coins(ein(.defi, correct: 10, total: 10)), 150, "defi sans faute")
eq(Economy.coins(ein(.defi, correct: 9, total: 10)), 50, "defi 1 erreur")
eq(Economy.coins(ein(.defi, correct: 8, total: 10)), 30, "defi 2 erreurs")
eq(Economy.coins(ein(.defi, correct: 5, total: 10)), 0, "defi 5 erreurs")

// MARK: Quiz session
do {
    var s = QuizSession(mode: .survie, difficulty: .normal, categoryID: "histoire",
                        questions: [q("1", correct: 1), q("2", correct: 2), q("3", correct: 0)])
    eq(s.submit(answerIndex: 1, remainingFraction: 1.0).gainedScore, 200, "q1 score"); s.advance()
    eq(s.submit(answerIndex: 2, remainingFraction: 0.0).gainedScore, 100, "q2 score"); s.advance()
    let last = s.submit(answerIndex: 0, remainingFraction: 0.5)
    eq(last.gainedScore, 150, "q3 score"); check(last.endsGame, "q3 ends")
    eq(s.score, 450, "total score"); eq(s.correctCount, 3, "correct count")
    eq(s.bestStreak, 3, "best streak"); eq(s.fastCount, 1, "fast count"); check(s.perfect, "perfect")
    let r = s.makeResult(previousBest: 0)
    eq(r.xpEarned, 30, "xp earned"); check(r.isNewRecord, "new record"); check(r.coinsEarned > 0, "coins > 0")
}
do {
    var s = QuizSession(mode: .survie, difficulty: .normal, categoryID: "histoire",
                        questions: [q("1", correct: 0), q("2", correct: 0), q("3", correct: 0)])
    _ = s.submit(answerIndex: 0, remainingFraction: 0.8); s.advance()
    let o = s.submit(answerIndex: 3, remainingFraction: 0.8)
    check(!o.wasCorrect && o.endsGame, "survie ends on wrong")
    eq(s.correctCount, 1, "survie correct"); check(!s.perfect, "survie not perfect")
}

// MARK: Profile mutation
do {
    var p = PlayerProfile(pseudo: "Test")
    let res = GameResult(mode: .survie, difficulty: .normal, categoryID: "histoire", score: 500,
                         maxScore: 3000, correctCount: 8, total: 15, bestStreak: 5, coinsEarned: 10,
                         xpEarned: 200, isNewRecord: true, duelWon: nil)
    let applied = p.apply(result: res, day: 20_260_605)
    eq(p.totalXP, 200, "profile xp"); eq(p.level, 2, "profile level")
    eq(applied.leveledUpTo, [2], "leveled up to"); eq(applied.levelRewardCoins, 20, "level reward")
    eq(p.coins, 30, "profile coins"); check(applied.newRecord, "applied new record")
    eq(p.bestScore(mode: .survie, categoryID: "histoire", difficulty: .normal), 500, "best score stored")
}
do {
    var p = PlayerProfile(pseudo: "Test")
    let day = 20_260_605
    func training(_ c: Int) -> GameResult {
        GameResult(mode: .entrainement, difficulty: .facile, categoryID: "histoire", score: 0, maxScore: 0,
                   correctCount: 0, total: 0, bestStreak: 0, coinsEarned: c, xpEarned: 0, isNewRecord: false, duelWon: nil)
    }
    p.apply(result: training(15), day: day); p.apply(result: training(15), day: day); p.apply(result: training(15), day: day)
    eq(p.coins, 20, "training cap same day")
    p.apply(result: training(15), day: day + 1)
    eq(p.coins, 35, "training cap resets next day")
}
do {
    var p = PlayerProfile(pseudo: "Test"); p.coins = 10
    let loss = GameResult(mode: .duel, difficulty: .normal, categoryID: nil, score: 0, maxScore: 1400,
                          correctCount: 0, total: 7, bestStreak: 0, coinsEarned: -15, xpEarned: 0, isNewRecord: false, duelWon: false)
    p.apply(result: loss, day: 1)
    eq(p.coins, 0, "duel wallet floor")
}

// MARK: Daily challenge & RNG & bank
do {
    let pool = (0..<30).map { q("d\($0)") }
    let day = DailyChallenge.day(year: 2026, month: 6, day: 5)
    let a = DailyChallenge.questions(from: pool, day: day)
    let b = DailyChallenge.questions(from: pool, day: day)
    eq(a.map(\.id), b.map(\.id), "daily deterministic")
    eq(a.count, DailyChallenge.questionCount, "daily count")
    check(a.map(\.id) != DailyChallenge.questions(from: pool, day: day + 1).map(\.id), "daily differs next day")
}
do {
    var g1 = SeededGenerator(seed: 42); var g2 = SeededGenerator(seed: 42)
    eq((0..<5).map { _ in g1.next() }, (0..<5).map { _ in g2.next() }, "seeded rng deterministic")
}
do {
    let bank = QuestionBank(all: [q("a", cat: "sport"), q("b", cat: "sport")])
    eq(bank.query(categoryID: "sport", difficulty: nil, count: 5).count, 5, "bank cycles to fill")
    eq(bank.query(categoryID: "sport", difficulty: nil, count: 2, seed: 7).map(\.id),
       bank.query(categoryID: "sport", difficulty: nil, count: 2, seed: 7).map(\.id), "bank seeded reproducible")
    eq(bank.query(categoryID: Category.melange.id, difficulty: nil, count: 2).count, 2, "bank melange")
}
eq(Category.all.count, 13, "categories count")
check(!AvatarItem.catalog.isEmpty, "catalog not empty")
eq(Set(AvatarItem.catalog.map(\.id)).count, AvatarItem.catalog.count, "catalog unique ids")

// MARK: Price grid (rescale 200..50000, dense 500-3000)
do {
    let purchasable = AvatarItem.catalog.filter { $0.unlockLevel == nil }
    let locked = AvatarItem.catalog.filter { $0.unlockLevel != nil }
    let bands: [Rarity: ClosedRange<Int>] = [
        .commun: 200...450, .rare: 500...1500, .epique: 1500...3500, .legendaire: 6000...50000,
    ]
    eq(purchasable.map(\.price).min() ?? 0, 200, "price floor is 200")
    eq(AvatarItem.item(id: "haut.tshirt")?.price ?? 0, 200, "floor item is haut.tshirt")
    eq(purchasable.map(\.price).max() ?? 0, 50000, "price ceiling is 50000")
    eq(AvatarItem.item(id: "fond.trounoir")?.price ?? 0, 50000, "ceiling item is fond.trounoir")
    check(purchasable.allSatisfy { bands[$0.rarity]?.contains($0.price) ?? false }, "each price in its rarity band")
    check(locked.count == 5 && locked.allSatisfy { $0.price == 0 && $0.unlockLevel != nil }, "5 level-locked items keep price 0")
    let inMidBand = purchasable.filter { (500...3000).contains($0.price) }.count
    check(inMidBand >= 24, "bulk of catalog in 500-3000 band (got \(inMidBand))")
}

// MARK: Bundled question bank (Resources/questions.json)
// Decodes the real bank with the production model and enforces content invariants:
// >=100 questions per category, exactly 4 answers, a non-empty explanation each,
// unique ids and unique texts. Run from the package root (`swift run KwizzCoreCheck`).
do {
    let path = "Resources/questions.json"
    if let data = FileManager.default.contents(atPath: path) {
        do {
            let qs = try JSONDecoder().decode([Question].self, from: data)
            check(qs.count >= 1000, "question bank size (got \(qs.count))")
            check(qs.allSatisfy { $0.isValid }, "all questions valid")
            check(qs.allSatisfy { $0.answers.count == 4 }, "all questions have exactly 4 answers")
            check(qs.allSatisfy { ($0.explanation?.isEmpty == false) }, "all questions have a non-empty explanation")
            eq(Set(qs.map(\.id)).count, qs.count, "question ids unique")
            eq(Set(qs.map { $0.text.lowercased() }).count, qs.count, "question texts unique")
            let known = Set(Category.all.map(\.id))
            check(qs.allSatisfy { known.contains($0.categoryID) }, "all categoryIDs known")
            var perCat: [String: Int] = [:]
            for question in qs { perCat[question.categoryID, default: 0] += 1 }
            for cat in Category.all {
                check((perCat[cat.id] ?? 0) >= 100, "category \(cat.id) has >=100 questions (got \(perCat[cat.id] ?? 0))")
            }
        } catch {
            check(false, "questions.json decodes: \(error)")
        }
    } else {
        print("  (skip) Resources/questions.json not found from \(FileManager.default.currentDirectoryPath)")
    }
}

// MARK: DayKey (serial day, correct across month/year boundaries)
eq(DayKey.serial(20260605) - DayKey.serial(20260604), 1, "serial consecutive days")
eq(DayKey.serial(20260601) - DayKey.serial(20260531), 1, "serial across month boundary")
eq(DayKey.serial(20270101) - DayKey.serial(20261231), 1, "serial across year boundary")
eq(DayKey.serial(20260605) - DayKey.serial(20260603), 2, "serial two-day gap")

// MARK: Chest chance + welcome top-up
check(Economy.chestChance(mode: .classique, correctCount: 15, total: 30) == 0, "chest chance 50% acc -> 0")
check(abs(Economy.chestChance(mode: .classique, correctCount: 30, total: 30) - 0.60) < 1e-9, "chest chance perfect -> 0.60")
check(abs(Economy.chestChance(mode: .classique, correctCount: 24, total: 30) - 0.30) < 1e-9, "chest chance 80% acc -> 0.30")
check(Economy.chestChance(mode: .entrainement, correctCount: 30, total: 30) == 0, "training never drops chests")
check(Economy.chestChance(mode: .survie, correctCount: 20, total: 20) == 0.60, "survie target -> 0.60")
eq(Economy.chestAwarded(mode: .classique, correctCount: 30, total: 30, seed: 7),
   Economy.chestAwarded(mode: .classique, correctCount: 30, total: 30, seed: 7), "chest roll deterministic")
eq(Economy.welcomeTopUp(currentCoins: 50), 150, "welcome top-up from 50")
eq(Economy.welcomeTopUp(currentCoins: 250), 0, "welcome top-up never negative")

// MARK: Daily wheel
eq(DailyWheel.prizes.map(\.weight).reduce(0, +), 10000, "wheel weights sum 10000")
eq(DailyWheel.spin(day: 20260605), DailyWheel.spin(day: 20260605), "wheel deterministic same day")
check(abs(DailyWheel.expectedValue - 50) < 3, "wheel EV ~50 (got \(DailyWheel.expectedValue))")
// Jackpot: 10000 pièces, dernier lot, poids 1 sur 10000 = 0,01 %.
eq(DailyWheel.prizes.last?.coins ?? 0, 10000, "jackpot is the last prize")
eq(DailyWheel.prizes.last?.weight ?? 0, 1, "jackpot weight is 1 (0.01%)")
check(DailyWheel.prizes.map(\.coins).max() == 10000, "top prize is 10000 coins")
do {
    let coinsSet = Set(DailyWheel.prizes.map(\.coins))
    check((0..<200).allSatisfy { coinsSet.contains(DailyWheel.spin(day: 20260000 + $0)) }, "wheel result always in table")
    check((0..<200).contains { DailyWheel.spin(day: 20260000 + $0) != DailyWheel.spin(day: 20260000) }, "wheel varies by day")
}

// MARK: Mystery chests
eq(MysteryChest.coinPrizes.map(\.weight).reduce(0, +), 100, "chest coin weights sum 100")
eq(MysteryChest.rarityWeights.map(\.weight).reduce(0, +), 100, "chest rarity weights sum 100")
check(abs(MysteryChest.coinExpectedValue - 55) < 2, "chest coin EV ~55 (got \(MysteryChest.coinExpectedValue))")
eq(MysteryChest.open(open: 0, owned: []), MysteryChest.open(open: 0, owned: []), "chest open deterministic")
check((0..<30).contains { MysteryChest.open(open: $0, owned: []) != MysteryChest.open(open: 0, owned: []) }, "chest opens vary")
do {
    let chestCoins = Set(MysteryChest.coinPrizes.map(\.coins))
    check((0..<300).allSatisfy { let r = MysteryChest.open(open: $0, owned: []); return r.isItem || chestCoins.contains(r.coins) }, "chest coins always in table")
    check((0..<300).contains { MysteryChest.open(open: $0, owned: []).isItem }, "chest can drop an item")
    let allOwned = Set(AvatarItem.catalog.map(\.id))
    check((0..<100).allSatisfy { !MysteryChest.open(open: $0, owned: allOwned).isItem }, "chest falls back to coins when all owned")
}

// MARK: Streak milestones
eq(StreakMilestone.chests(forStreak: 3), 1, "milestone D3")
eq(StreakMilestone.chests(forStreak: 7), 1, "milestone D7")
eq(StreakMilestone.chests(forStreak: 14), 1, "milestone D14")
eq(StreakMilestone.chests(forStreak: 30), 1, "milestone D30")
eq(StreakMilestone.chests(forStreak: 60), 1, "milestone repeating 30")
eq(StreakMilestone.chests(forStreak: 45), 0, "no milestone off-cadence")
eq(StreakMilestone.chests(forStreak: 1), 0, "no milestone D1")
eq(StreakMilestone.next(after: 0), 3, "next milestone after 0")
eq(StreakMilestone.next(after: 7), 14, "next milestone after 7")
eq(StreakMilestone.next(after: 35), 60, "next milestone after 35")

// MARK: Achievements
eq(Achievement.catalog.count, 6, "six achievements")
eq(Set(Achievement.catalog.map(\.id)).count, 6, "achievement ids unique")
do {
    let ctx = AchievementContext(gamesPlayed: 1, level: 1, dailyStreak: 1, totalCorrect: 0, lastWasPerfect: false)
    let first = Achievement.evaluate(ctx, already: [])
    check(first.contains { $0.id == "premiere_partie" }, "premiere_partie unlocks at game 1")
    check(!Achievement.evaluate(ctx, already: ["premiere_partie"]).contains { $0.id == "premiere_partie" }, "no double unlock")
    let perfectCtx = AchievementContext(gamesPlayed: 2, level: 1, dailyStreak: 1, totalCorrect: 0, lastWasPerfect: true)
    check(Achievement.evaluate(perfectCtx, already: []).contains { $0.id == "sans_faute" }, "sans_faute on perfect game")
}

// MARK: Profile integration (streak by any game, chests, welcome bonus, decode)
func gr(mode: GameMode = .classique, correct: Int = 20, total: Int = 30, perfect: Bool = false) -> GameResult {
    GameResult(mode: mode, difficulty: .normal, categoryID: "melange", score: 1000, maxScore: 3000,
               correctCount: perfect ? total : correct, total: total, bestStreak: 5, coinsEarned: 30,
               xpEarned: 10, isNewRecord: false, duelWon: nil)
}
do {
    var p = PlayerProfile(pseudo: "S")
    p.apply(result: gr(), day: 20260601); eq(p.dailyStreak, 1, "streak day 1")
    p.apply(result: gr(), day: 20260601); eq(p.dailyStreak, 1, "streak unchanged same day")
    p.apply(result: gr(), day: 20260602); eq(p.dailyStreak, 2, "streak consecutive day")
    p.apply(result: gr(), day: 20260604); eq(p.dailyStreak, 1, "streak resets after a missed day")
}
do {
    var p = PlayerProfile(pseudo: "M")
    for d in [20260601, 20260602, 20260603] { p.apply(result: gr(), day: d) }
    eq(p.dailyStreak, 3, "streak reaches 3")
    check(p.ownedChests >= 2, "D3 milestone + premiere_partie grant chests (got \(p.ownedChests))")
}
do {
    var p = PlayerProfile(pseudo: "W")
    p.apply(result: gr(), day: 20260601)
    check(p.firstGameDone, "first game flagged")
    p.applyWelcomeBonusIfNeeded()
    check(p.coins >= Economy.welcomeFloor, "welcome floor reached after first game")
    let before = p.coins
    p.applyWelcomeBonusIfNeeded()
    eq(p.coins, before, "welcome bonus applies once")
}
do {
    let json = Data("{\"pseudo\":\"Old\",\"coins\":5}".utf8)
    if let p = try? JSONDecoder().decode(PlayerProfile.self, from: json) {
        eq(p.coins, 5, "legacy decode keeps coins")
        eq(p.ownedChests, 0, "legacy decode default ownedChests")
        eq(p.unlockedAchievementIDs.count, 0, "legacy decode default achievements")
        check(!p.welcomeBonusGranted, "legacy decode default welcomeBonusGranted")
    } else {
        check(false, "legacy profile decodes")
    }
}

// MARK: Room code (online duel)
do {
    var gen = SeededGenerator(seed: 42)
    let code = RoomCode.generate(using: &gen)
    eq(code.count, 5, "room code length")
    check(RoomCode.isValid(code), "generated code is valid")
    check(code.allSatisfy { RoomCode.alphabet.contains($0) }, "code uses alphabet only")
    var gen2 = SeededGenerator(seed: 42)
    eq(RoomCode.generate(using: &gen2), code, "seeded code is reproducible")
    check(!RoomCode.alphabet.contains("O") && !RoomCode.alphabet.contains("0"), "no O/0 in alphabet")
    check(!RoomCode.alphabet.contains("I") && !RoomCode.alphabet.contains("1") && !RoomCode.alphabet.contains("L"), "no I/1/L in alphabet")
    eq(RoomCode.normalize(" k7qx9 "), "K7QX9", "normalize trims and uppercases")
    eq(RoomCode.normalize("k7-qx9"), "K7QX9", "normalize drops stray chars")
    check(!RoomCode.isValid("ABC"), "too short is invalid")
    check(!RoomCode.isValid("ABCDE9X"), "too long is invalid")
    check(!RoomCode.isValid("ABCD0"), "char outside alphabet is invalid")
}

// MARK: Duel protocol (Codable round-trip)
func roundtripEvent(_ e: DuelEvent) -> DuelEvent? {
    guard let data = try? JSONEncoder().encode(e) else { return nil }
    return try? JSONDecoder().decode(DuelEvent.self, from: data)
}
do {
    let p = DuelPlayer(clientID: "c1", pseudo: "Alice", accentHex: "#00ff88", isHost: true)
    let a = DuelAnswer(answerIndex: 1, correct: true, elapsedMs: 1840)
    let events: [DuelEvent] = [
        .hello(player: p),
        .start(questions: [q("1"), q("2")], roundID: "r1"),
        .beginQuestion(index: 0),
        .answer(clientID: "c1", index: 0, answer: a),
        .reveal(index: 0, answers: ["c1": a], winner: "c1"),
        .finish,
    ]
    for e in events { check(roundtripEvent(e) == e, "DuelEvent round-trips: \(e)") }
}

// MARK: Duel match (synchronised, first-correct-wins)
func dpl(_ id: String, _ name: String) -> DuelPlayer { DuelPlayer(clientID: id, pseudo: name) }
func ans(_ idx: Int?, _ correct: Bool, _ ms: Int) -> DuelAnswer { DuelAnswer(answerIndex: idx, correct: correct, elapsedMs: ms) }
do {
    var m = DuelMatch(roomCode: "K7QX9", localClientID: "h", host: dpl("h", "Host"))
    eq(m.phase, .lobby, "match starts in lobby")
    check(m.isHost, "local is host")
    check(!m.canStart, "cannot start with one player")
    m.playerJoined(dpl("g1", "Guest1"))
    check(m.canStart, "host can start at two players")
    m.playerJoined(dpl("g1", "Guest1"))
    eq(m.players.count, 2, "duplicate join ignored")
    for g in ["g2", "g3", "g4", "g5", "g6"] { m.playerJoined(dpl(g, g)) }
    eq(m.players.count, 6, "room caps at six")
    check(m.isFull, "room full at six")
}
do {
    var m = DuelMatch(roomCode: "ABCDE", localClientID: "h", host: dpl("h", "Host"))
    m.playerJoined(dpl("a", "Anna"))
    m.playerJoined(dpl("b", "Bob"))
    m.apply(.start(questions: [q("1"), q("2")], roundID: "r1"))
    eq(m.phase, .countdown, "start moves to countdown")
    eq(m.points.count, 3, "points seeded for all players")

    // Q0: host and Anna correct, Anna faster -> Anna takes the only point.
    m.apply(.beginQuestion(index: 0))
    eq(m.phase, .question(index: 0), "question 0 open")
    m.apply(.answer(clientID: "h", index: 0, answer: ans(0, true, 2200)))
    m.apply(.answer(clientID: "a", index: 0, answer: ans(0, true, 1200)))
    m.apply(.answer(clientID: "b", index: 0, answer: ans(1, false, 900)))
    check(m.allAnswered(0), "all three answered q0")
    eq(m.computeWinner(0) ?? "?", "a", "fastest correct wins (Anna)")
    m.apply(.reveal(index: 0, answers: m.snapshot(0), winner: m.computeWinner(0)))
    eq(m.phase, .reveal(index: 0), "reveal 0")
    eq(m.points["a"] ?? -1, 1, "Anna +1 point")
    eq(m.points["h"] ?? -1, 0, "host 0 (slower despite correct)")
    eq(m.points["b"] ?? -1, 0, "Bob 0 (wrong)")

    // Q1: nobody correct -> no point awarded.
    m.apply(.beginQuestion(index: 1))
    m.apply(.answer(clientID: "h", index: 1, answer: ans(2, false, 1000)))
    m.apply(.answer(clientID: "a", index: 1, answer: ans(nil, false, 15000)))
    m.apply(.answer(clientID: "b", index: 1, answer: ans(3, false, 800)))
    check(m.computeWinner(1) == nil, "no winner when nobody is correct")
    m.apply(.reveal(index: 1, answers: m.snapshot(1), winner: m.computeWinner(1)))
    eq(m.points["a"] ?? -1, 1, "no extra point on q1")

    // Recap data survives for the end screen.
    eq(m.answer(of: "b", at: 0)?.answerIndex ?? -1, 1, "recap keeps Bob's q0 choice")
    eq(m.correctCount(of: "a"), 1, "Anna has one correct overall")

    m.apply(.finish)
    eq(m.phase, .finished, "match finished")
    let board = m.scoreboard
    eq(board.first?.player.clientID ?? "?", "a", "Anna leads the podium")
    eq(board.first?.rank ?? -1, 1, "Anna rank 1")
}
do {
    // Leaving removes a player from the present set (stops blocking all-answered).
    var m = DuelMatch(roomCode: "ABCDE", localClientID: "h", host: dpl("h", "Host"))
    m.playerJoined(dpl("a", "Anna"))
    m.apply(.start(questions: [q("1")], roundID: "r1"))
    m.apply(.beginQuestion(index: 0))
    m.apply(.answer(clientID: "h", index: 0, answer: ans(0, true, 1000)))
    check(!m.allAnswered(0), "not all answered while Anna is present")
    m.playerLeft(clientID: "a")
    check(m.allAnswered(0), "host alone counts as all-answered after Anna leaves")
}

// MARK: Elo / ranked tiers
eq(Elo.start, 1000, "elo start")
check(abs(Elo.expectedScore(rating: 1500, opponent: 1500) - 0.5) < 1e-9, "expected 0.5 at equal")
check(Elo.expectedScore(rating: 1900, opponent: 1500) > 0.9, "favorite expected > 0.9")
eq(Elo.updatedRating(rating: 1500, opponent: 1500, won: true), 1510, "win at equal +10")
eq(Elo.updatedRating(rating: 1500, opponent: 1500, won: false), 1490, "loss at equal -10")
check(Elo.updatedRating(rating: 1500, opponent: 1900, won: true) > 1510, "upset win gains more")
check(Elo.updatedRating(rating: 1900, opponent: 1500, won: true) < 1910, "favorite win gains less")
eq(Elo.updatedRating(rating: 0, opponent: 2000, won: false), 0, "rating floored at 0")
eq(RankTier.tier(forRating: 0), .bronze, "tier @0")
eq(RankTier.tier(forRating: 1199), .bronze, "tier @1199")
eq(RankTier.tier(forRating: 1200), .argent, "tier @1200")
eq(RankTier.tier(forRating: 2199), .master, "tier @2199")
eq(RankTier.tier(forRating: 2200), .grandMaster, "tier @2200")
eq(RankTier.tier(forRating: 9999), .grandMaster, "tier @max")
check(RankTier.grandMaster.progress(rating: 5000) == 1, "GM progress capped at 1")
check(abs(RankTier.argent.progress(rating: 1300) - 0.5) < 1e-9, "argent mid progress 0.5")

// Duel / ranked stake: win +stake, loss -stake, draw (duelWon nil) -> 0.
func duelInput(_ won: Bool?) -> Economy.Input {
    Economy.Input(mode: .duel, coinMultiplier: 1, correctCount: 3, total: 7, perfect: false,
                  bestStreak: 0, fastCount: 0, scoreFraction: 0.5, duelWon: won)
}
eq(Economy.coins(duelInput(true)), Economy.duelStake, "duel win = +stake")
eq(Economy.coins(duelInput(false)), -Economy.duelStake, "duel loss = -stake")
eq(Economy.coins(duelInput(nil)), 0, "duel draw = 0 stake")

// MARK: Report
print("")
print("KwizzCore verification: \(total - failures)/\(total) checks passed")
if failures > 0 {
    print("\(failures) FAILURE(S)")
    exit(1)
} else {
    print("ALL GREEN ✅")
}

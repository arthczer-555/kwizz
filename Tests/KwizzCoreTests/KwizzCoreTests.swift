import Testing
@testable import KwizzCore

private func q(_ id: String, cat: String = "histoire", sub: String? = nil,
               diff: Difficulty = .normal, correct: Int = 0) -> Question {
    Question(id: id, categoryID: cat, subcategoryID: sub, difficulty: diff,
             text: "Q \(id) ?", answers: ["A", "B", "C", "D"], correctIndex: correct)
}

@Suite struct LevelTableTests {
    @Test func shape() {
        #expect(LevelTable.xpToNext.count == 19)
        #expect(LevelTable.cumulative.count == 20)
        #expect(LevelTable.cumulative.first == 0)
        #expect(LevelTable.totalToMax == 238_850)
        #expect(LevelTable.title(level: 1) == "Niveau 1")
        #expect(LevelTable.title(level: 20) == "Niveau 20")
        for i in 1..<LevelTable.cumulative.count {
            #expect(LevelTable.cumulative[i] > LevelTable.cumulative[i - 1])
        }
    }

    @Test func boundaries() {
        #expect(LevelTable.level(totalXP: 0) == 1)
        #expect(LevelTable.level(totalXP: 149) == 1)
        #expect(LevelTable.level(totalXP: 150) == 2)
        #expect(LevelTable.level(totalXP: 449) == 2)
        #expect(LevelTable.level(totalXP: 450) == 3)
        #expect(LevelTable.level(totalXP: 238_849) == 19)
        #expect(LevelTable.level(totalXP: 238_850) == 20)
        #expect(LevelTable.level(totalXP: 9_000_000) == 20)
        #expect(LevelTable.level(totalXP: -50) == 1)
    }

    @Test func progress() {
        let p = LevelTable.progress(totalXP: 150)
        #expect(p.level == 2)
        #expect(p.xpIntoLevel == 0)
        #expect(p.xpForNextLevel == 300)
        #expect(abs(p.fraction) < 0.0001)
        #expect(p.isMax == false)

        let maxP = LevelTable.progress(totalXP: 500_000)
        #expect(maxP.isMax)
        #expect(abs(maxP.fraction - 1) < 0.0001)
    }

    @Test func rewards() {
        #expect(LevelTable.reward(reachingLevel: 2).coins == 20)
        #expect(LevelTable.reward(reachingLevel: 2).itemRarity == nil)
        #expect(LevelTable.reward(reachingLevel: 5).itemRarity == .commun)
        #expect(LevelTable.reward(reachingLevel: 10).itemRarity == .rare)
        #expect(LevelTable.reward(reachingLevel: 15).itemRarity == .epique)
        #expect(LevelTable.reward(reachingLevel: 20).itemRarity == .legendaire)
    }
}

@Suite struct GameModeTests {
    /// Toute manche à compteur fixe fait 15 questions ; seul le Duel, joué en
    /// direct contre un adversaire, reste plus court.
    @Test func questionCounts() {
        #expect(GameMode.standardQuestionCount == 15)
        for mode in [GameMode.classique, .entrainement] {
            #expect(mode.questionCount == 15)
        }
        // Manches plus courtes : direct contre un adversaire, et grille du jour.
        #expect(GameMode.duel.questionCount == 7)
        #expect(GameMode.defi.questionCount == 10)
        #expect(DailyChallenge.questionCount == 10)
        // Bornés par autre chose qu'un compteur : 60 s, et la 1re erreur.
        #expect(GameMode.contreLaMontre.questionCount == nil)
        #expect(GameMode.survie.questionCount == nil)
    }
}

@Suite struct ScoringEconomyTests {
    @Test func scoring() {
        #expect(Scoring.questionScore(correct: true, remainingFraction: 1.0, hasSpeedBonus: true) == 200)
        #expect(Scoring.questionScore(correct: true, remainingFraction: 0.0, hasSpeedBonus: true) == 100)
        #expect(Scoring.questionScore(correct: true, remainingFraction: 0.5, hasSpeedBonus: true) == 150)
        #expect(Scoring.questionScore(correct: false, remainingFraction: 1.0, hasSpeedBonus: true) == 0)
        #expect(Scoring.questionScore(correct: true, remainingFraction: 1.0, hasSpeedBonus: false) == 100)
        #expect(Scoring.maxScore(questionCount: 15) == 3000)
        #expect(Scoring.maxScore(questionCount: 30, hasSpeedBonus: false) == 3000)
    }

    @Test func economyPerMode() {
        func input(_ mode: GameMode, _ diff: Difficulty = .normal, correct: Int = 10, total: Int = 10, fast: Int = 0,
                   perfect: Bool = false, streak: Int = 0, frac: Double = 0, duel: Bool? = nil) -> Economy.Input {
            Economy.Input(mode: mode, coinMultiplier: diff.coinMultiplier, correctCount: correct, total: total,
                          perfect: perfect, bestStreak: streak, fastCount: fast, scoreFraction: frac, duelWon: duel)
        }
        // Entraînement: 1 pièce par 3 bonnes réponses, cap 20/jour appliqué par le store.
        #expect(Economy.coins(input(.entrainement, .facile, correct: 15, total: 15)) == 5)
        #expect(Economy.coins(input(.entrainement, .facile, correct: 2, total: 15)) == 0)
        // Classique: base x multiplicateur de difficulté, puis +20% (classiqueBonus).
        #expect(Economy.coins(input(.classique, .normal, correct: 15, total: 15)) == 27)
        #expect(Economy.coins(input(.classique, .facile, correct: 10, total: 15)) == 12)
        #expect(Economy.coins(input(.contreLaMontre, .normal, correct: 14)) == 21)
        #expect(Economy.coins(input(.survie, .facile, correct: 12, streak: 12)) == 14)
        #expect(Economy.coins(input(.duel, duel: true)) == 15)
        #expect(Economy.coins(input(.duel, duel: false)) == -15)
        // Défi du jour: dégressif, fortement orienté sans faute.
        #expect(Economy.coins(input(.defi, correct: 10, total: 10)) == 150)
        #expect(Economy.coins(input(.defi, correct: 9, total: 10)) == 50)
        #expect(Economy.coins(input(.defi, correct: 8, total: 10)) == 30)
        #expect(Economy.coins(input(.defi, correct: 5, total: 10)) == 0)
    }

    @Test func defiReward() {
        #expect(Economy.defiReward(errors: 0) == 150)
        #expect(Economy.defiReward(errors: 1) == 50)
        #expect(Economy.defiReward(errors: 2) == 30)
        #expect(Economy.defiReward(errors: 3) == 20)
        #expect(Economy.defiReward(errors: 4) == 10)
        #expect(Economy.defiReward(errors: 5) == 0)
        #expect(Economy.defiReward(errors: 99) == 0)
    }
}

@Suite struct QuizSessionTests {
    @Test func flow() {
        let questions = [q("1", correct: 1), q("2", correct: 2), q("3", correct: 0)]
        var s = QuizSession(mode: .survie, difficulty: .normal, categoryID: "histoire", questions: questions)

        var o = s.submit(answerIndex: 1, remainingFraction: 1.0)
        #expect(o.wasCorrect); #expect(o.gainedScore == 200); #expect(o.endsGame == false)
        s.advance()
        o = s.submit(answerIndex: 2, remainingFraction: 0.0)
        #expect(o.gainedScore == 100)
        s.advance()
        o = s.submit(answerIndex: 0, remainingFraction: 0.5)
        #expect(o.gainedScore == 150); #expect(o.endsGame)

        #expect(s.score == 450)
        #expect(s.correctCount == 3)
        #expect(s.bestStreak == 3)
        #expect(s.fastCount == 1)
        #expect(s.perfect)

        let result = s.makeResult(previousBest: 0)
        #expect(result.xpEarned == 30)
        #expect(result.isNewRecord)
        #expect(result.coinsEarned > 0)
    }

    @Test func survieEndsOnWrong() {
        let questions = [q("1", correct: 0), q("2", correct: 0), q("3", correct: 0)]
        var s = QuizSession(mode: .survie, difficulty: .normal, categoryID: "histoire", questions: questions)
        _ = s.submit(answerIndex: 0, remainingFraction: 0.8)
        s.advance()
        let o = s.submit(answerIndex: 3, remainingFraction: 0.8)
        #expect(o.wasCorrect == false)
        #expect(o.endsGame)
        #expect(s.correctCount == 1)
        #expect(s.perfect == false)
    }
}

@Suite struct ProfileTests {
    @Test func applyCoinsXPLevelUp() {
        var profile = PlayerProfile(pseudo: "Test")
        let result = GameResult(mode: .survie, difficulty: .normal, categoryID: "histoire",
                                score: 500, maxScore: 3000, correctCount: 8, total: 15, bestStreak: 5,
                                coinsEarned: 10, xpEarned: 200, isNewRecord: true, duelWon: nil)
        let applied = profile.apply(result: result, day: 20_260_605)
        #expect(profile.totalXP == 200)
        #expect(profile.level == 2)
        #expect(applied.leveledUpTo == [2])
        #expect(applied.levelRewardCoins == 20)
        #expect(profile.coins == 30)
        #expect(applied.newRecord)
        #expect(profile.bestScore(mode: .survie, categoryID: "histoire", difficulty: .normal) == 500)
        #expect(profile.gamesPlayed == 1)
    }

    @Test func trainingDailyCap() {
        var profile = PlayerProfile(pseudo: "Test")
        let day = 20_260_605
        func training(_ coins: Int) -> GameResult {
            GameResult(mode: .entrainement, difficulty: .facile, categoryID: "histoire", score: 0, maxScore: 0,
                       correctCount: 0, total: 0, bestStreak: 0, coinsEarned: coins, xpEarned: 0,
                       isNewRecord: false, duelWon: nil)
        }
        profile.apply(result: training(15), day: day)
        profile.apply(result: training(15), day: day)
        profile.apply(result: training(15), day: day)
        #expect(profile.coins == 20)
        profile.apply(result: training(15), day: day + 1)
        #expect(profile.coins == 35)
    }

    @Test func duelWalletFloor() {
        var profile = PlayerProfile(pseudo: "Test")
        profile.coins = 10
        let loss = GameResult(mode: .duel, difficulty: .normal, categoryID: nil, score: 0, maxScore: 1400,
                              correctCount: 0, total: 7, bestStreak: 0, coinsEarned: -15, xpEarned: 0,
                              isNewRecord: false, duelWon: false)
        profile.apply(result: loss, day: 1)
        #expect(profile.coins == 0)
    }
}

@Suite struct DailyAndBankTests {
    @Test func dailyDeterministic() {
        let pool = (0..<30).map { q("d\($0)") }
        let day = DailyChallenge.day(year: 2026, month: 6, day: 5)
        let a = DailyChallenge.questions(from: pool, day: day)
        let b = DailyChallenge.questions(from: pool, day: day)
        #expect(a.map(\.id) == b.map(\.id))
        #expect(a.count == DailyChallenge.questionCount)
        let other = DailyChallenge.questions(from: pool, day: day + 1)
        #expect(a.map(\.id) != other.map(\.id))
    }

    @Test func seededGenerator() {
        var g1 = SeededGenerator(seed: 42)
        var g2 = SeededGenerator(seed: 42)
        #expect((0..<5).map { _ in g1.next() } == (0..<5).map { _ in g2.next() })
    }

    @Test func questionBankQuery() {
        let bank = QuestionBank(all: [q("a", cat: "sport"), q("b", cat: "sport")])
        #expect(bank.query(categoryID: "sport", difficulty: nil, count: 5).count == 5)
        let s1 = bank.query(categoryID: "sport", difficulty: nil, count: 2, seed: 7).map(\.id)
        let s2 = bank.query(categoryID: "sport", difficulty: nil, count: 2, seed: 7).map(\.id)
        #expect(s1 == s2)
        #expect(bank.query(categoryID: Category.melange.id, difficulty: nil, count: 2).count == 2)
    }

    /// Entraînement « toutes les difficultés » : la banque ne filtre pas, et la
    /// manche paie la moyenne des multiplicateurs des questions réussies.
    @Test func allDifficultiesTraining() {
        let pool = [q("f", diff: .facile), q("n", diff: .normal), q("d", diff: .difficile)]
        let drawn = QuestionBank(all: pool).query(categoryID: nil, difficulty: nil, count: 3)
        #expect(Set(drawn.map(\.difficulty)) == Set(Difficulty.allCases))

        var session = QuizSession(mode: .entrainement, difficulty: nil, categoryID: "histoire", questions: pool)
        for _ in pool {
            session.submit(answerIndex: 0, remainingFraction: 1)
            session.advance()
        }
        let result = session.makeResult(previousBest: 0)
        #expect(result.difficulty == nil)
        #expect(result.correctCount == 3)
        // Un tirage mixte s'enregistre sous une clé de record distincte.
        #expect(PlayerProfile.recordKey(mode: .entrainement, categoryID: "histoire", difficulty: nil)
                == "entrainement|histoire|toutes")
    }

    @Test func catalogIntegrity() {
        #expect(Category.all.count == 13)
        #expect(AvatarItem.catalog.isEmpty == false)
        #expect(Set(AvatarItem.catalog.map(\.id)).count == AvatarItem.catalog.count)
        #expect(Set(Category.all.map(\.id)).count == Category.all.count)
    }
}

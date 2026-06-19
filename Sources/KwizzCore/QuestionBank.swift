import Foundation

/// Holds the loaded questions and builds the list for a round.
public struct QuestionBank: Sendable {
    public let all: [Question]

    public init(all: [Question]) {
        self.all = all.filter { $0.isValid }
    }

    /// Decode a bank from `questions.json` data.
    public static func load(data: Data) throws -> QuestionBank {
        let questions = try JSONDecoder().decode([Question].self, from: data)
        return QuestionBank(all: questions)
    }

    public func count(categoryID: String?, difficulty: Difficulty?) -> Int {
        filtered(categoryID: categoryID, subcategoryID: nil, difficulty: difficulty).count
    }

    private func filtered(categoryID: String?, subcategoryID: String?, difficulty: Difficulty?) -> [Question] {
        var pool = all
        if let categoryID, categoryID != Category.melange.id {
            pool = pool.filter { $0.categoryID == categoryID }
        }
        if let subcategoryID {
            pool = pool.filter { $0.subcategoryID == subcategoryID }
        }
        if let difficulty {
            pool = pool.filter { $0.difficulty == difficulty }
        }
        return pool
    }

    /// Returns `count` questions for a round. If the matching pool is smaller than
    /// `count`, it cycles through the pool so the round always has enough questions.
    /// Pass a `seed` for reproducible ordering (daily challenge), otherwise the
    /// system RNG is used. `excluding` lists question IDs served recently: they are
    /// pushed to the back of the draw so fresh questions come first and consecutive
    /// games don't repeat, while still guaranteeing a full round when the pool is small.
    public func query(categoryID: String?, subcategoryID: String? = nil,
                      difficulty: Difficulty?, count: Int, seed: UInt64? = nil,
                      excluding: Set<String> = []) -> [Question] {
        var pool = filtered(categoryID: categoryID, subcategoryID: subcategoryID, difficulty: difficulty)
        // Fall back to ignoring the subcategory, then the difficulty, if too narrow.
        if pool.isEmpty {
            pool = filtered(categoryID: categoryID, subcategoryID: nil, difficulty: difficulty)
        }
        if pool.isEmpty {
            pool = filtered(categoryID: categoryID, subcategoryID: nil, difficulty: nil)
        }
        if pool.isEmpty { pool = all }
        guard !pool.isEmpty else { return [] }

        if let seed {
            var gen = SeededGenerator(seed: seed)
            pool.shuffle(using: &gen)
            return take(count, from: pool.map { $0.shuffledAnswers(using: &gen) })
        } else {
            pool.shuffle()
            // Bias the order so recently served questions are drawn last. `take`
            // then fills the round from fresh questions first.
            if !excluding.isEmpty {
                pool = pool.filter { !excluding.contains($0.id) } + pool.filter { excluding.contains($0.id) }
            }
            return take(count, from: pool).map { $0.shuffledAnswers() }
        }
    }

    /// Returns `count` questions, cycling through `pool` if it is too small.
    private func take(_ count: Int, from pool: [Question]) -> [Question] {
        if pool.count >= count { return Array(pool.prefix(count)) }
        var result = pool
        var i = 0
        while result.count < count {
            result.append(pool[i % pool.count])
            i += 1
        }
        return result
    }
}

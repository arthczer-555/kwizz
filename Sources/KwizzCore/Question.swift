import Foundation

/// A single multiple-choice question. Decoded from `questions.json`.
public struct Question: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let categoryID: String
    public let subcategoryID: String?
    public let difficulty: Difficulty
    public let text: String
    public let answers: [String]
    public let correctIndex: Int
    public let explanation: String?

    public init(
        id: String,
        categoryID: String,
        subcategoryID: String? = nil,
        difficulty: Difficulty,
        text: String,
        answers: [String],
        correctIndex: Int,
        explanation: String? = nil
    ) {
        self.id = id
        self.categoryID = categoryID
        self.subcategoryID = subcategoryID
        self.difficulty = difficulty
        self.text = text
        self.answers = answers
        self.correctIndex = correctIndex
        self.explanation = explanation
    }

    public var correctAnswer: String? {
        answers.indices.contains(correctIndex) ? answers[correctIndex] : nil
    }

    /// Returns a copy with the answer options reordered randomly, keeping
    /// `correctIndex` pointing at the correct answer. Pass a generator for a
    /// reproducible order (e.g. the Daily Challenge), otherwise use the
    /// no-argument overload which draws from the system RNG.
    public func shuffledAnswers<G: RandomNumberGenerator>(using generator: inout G) -> Question {
        let order = Array(answers.indices).shuffled(using: &generator)
        let reordered = order.map { answers[$0] }
        let newCorrect = order.firstIndex(of: correctIndex) ?? correctIndex
        return Question(
            id: id, categoryID: categoryID, subcategoryID: subcategoryID,
            difficulty: difficulty, text: text, answers: reordered,
            correctIndex: newCorrect, explanation: explanation
        )
    }

    public func shuffledAnswers() -> Question {
        var generator = SystemRandomNumberGenerator()
        return shuffledAnswers(using: &generator)
    }

    /// Basic integrity check used by the question loader / tests.
    public var isValid: Bool {
        answers.count >= 2 && answers.indices.contains(correctIndex) && !text.isEmpty
    }
}

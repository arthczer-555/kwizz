import Foundation

/// Loads the question bank from the bundled `questions.json`, with a small
/// built-in fallback so the app always has something to play even if the
/// resource is missing.
enum ContentLoader {
    static func loadBank() -> QuestionBank {
        if let url = Bundle.main.url(forResource: "questions", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let bank = try? QuestionBank.load(data: data),
           !bank.all.isEmpty {
            return bank
        }
        return QuestionBank(all: SampleQuestions.fallback)
    }
}

enum SampleQuestions {
    static let fallback: [Question] = [
        Question(id: "f1", categoryID: "geographie", subcategoryID: "geographie.0", difficulty: .facile,
                 text: "Quelle est la capitale de l'Australie ?", answers: ["Sydney", "Canberra", "Melbourne", "Perth"], correctIndex: 1),
        Question(id: "f2", categoryID: "sciences", subcategoryID: "sciences.5", difficulty: .facile,
                 text: "Combien de côtés a un hexagone ?", answers: ["Cinq", "Six", "Sept", "Huit"], correctIndex: 1),
        Question(id: "f3", categoryID: "arts", subcategoryID: "arts.0", difficulty: .normal,
                 text: "Qui a peint la Joconde ?", answers: ["Van Gogh", "Picasso", "Léonard de Vinci", "Dali"], correctIndex: 2),
        Question(id: "f4", categoryID: "histoire", subcategoryID: "histoire.3", difficulty: .normal,
                 text: "En quelle année débute la Révolution française ?", answers: ["1715", "1789", "1804", "1848"], correctIndex: 1),
        Question(id: "f5", categoryID: "sciences", subcategoryID: "sciences.0", difficulty: .facile,
                 text: "Quel gaz l'humain respire-t-il pour vivre ?", answers: ["Azote", "Hélium", "Oxygène", "Hydrogène"], correctIndex: 2),
        Question(id: "f6", categoryID: "geographie", subcategoryID: "geographie.2", difficulty: .normal,
                 text: "Quel est le plus grand pays du monde par superficie ?", answers: ["Canada", "Chine", "États-Unis", "Russie"], correctIndex: 3),
        Question(id: "f7", categoryID: "sport", subcategoryID: "sport.3", difficulty: .normal,
                 text: "Tous les combien d'années ont lieu les Jeux Olympiques d'été ?", answers: ["2 ans", "3 ans", "4 ans", "5 ans"], correctIndex: 2),
        Question(id: "f8", categoryID: "sciences", subcategoryID: "sciences.3", difficulty: .difficile,
                 text: "Quelle planète est la plus proche du Soleil ?", answers: ["Vénus", "Mars", "Mercure", "Terre"], correctIndex: 2),
        Question(id: "f9", categoryID: "histoire", subcategoryID: "histoire.0", difficulty: .difficile,
                 text: "Qui était le premier empereur romain ?", answers: ["Jules César", "Auguste", "Néron", "Trajan"], correctIndex: 1),
        Question(id: "f10", categoryID: "musique", subcategoryID: "musique.4", difficulty: .normal,
                 text: "Combien de cordes a une guitare classique standard ?", answers: ["Quatre", "Cinq", "Six", "Sept"], correctIndex: 2),
    ]
}

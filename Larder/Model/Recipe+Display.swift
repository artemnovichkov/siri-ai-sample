import Foundation
import NaturalLanguage

extension Recipe {
    /// "Italian · 1 hr 30 min". "Other" isn't a cuisine anyone wants to read, so it's left out.
    var byline: String {
        cuisine == .other ? duration : "\(cuisine.title) · \(duration)"
    }

    var duration: String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(rest) min"
        }
    }

    /// Instructions are stored as one string, so steps are its sentences.
    var steps: [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = instructions
        return tokenizer.tokens(for: instructions.startIndex..<instructions.endIndex)
            .map { instructions[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// A navigation value for a recipe. It's a type of its own so it can't collide with other string routes.
struct RecipeRoute: Hashable {
    let id: String
}

/// A filtered list of recipes that shelves and categories link to.
enum RecipeCollection: Hashable {
    case all, quick, unhurried, family
    case cuisine(Cuisine)

    var title: String {
        switch self {
        case .all: "All Recipes"
        case .quick: "Ready in 30 Minutes"
        case .unhurried: "Worth the Time"
        case .family: "Family Favorites"
        case .cuisine(let cuisine): cuisine.title
        }
    }

    func recipes(from all: [Recipe]) -> [Recipe] {
        switch self {
        case .all: all
        case .quick: all.filter { $0.minutes <= 30 }
        case .unhurried: all.filter { $0.minutes > 30 }
        case .family: all.filter { !$0.familyNotes.isEmpty }
        case .cuisine(let cuisine): all.filter { $0.cuisine == cuisine }
        }
    }
}

import FoundationModels

// Guided generation: the framework constrains sampling, so the model can't return malformed output.
// Properties generate in declaration order, which is also the order they appear while streaming.
// Keep descriptions short, because they use up the context window.

@Generable
enum IdeaCuisine {
    case italian, mexican, thai, middleEastern, other

    var cuisine: Cuisine {
        switch self {
        case .italian: .italian
        case .mexican: .mexican
        case .thai: .thai
        case .middleEastern: .middleEastern
        case .other: .other
        }
    }
}

@Generable(description: "A home-cooking recipe")
struct RecipeIdea {
    @Guide(description: "A short, appetizing dish name")
    var name: String

    @Guide(description: "One sentence on what the dish is")
    var summary: String

    var cuisine: IdeaCuisine

    @Guide(description: "Total time in minutes", .range(5...180))
    var minutes: Int

    @Guide(description: "Number of servings", .range(1...12))
    var servings: Int

    @Guide(description: "One ingredient with its amount, such as 400 g canned tomatoes", .count(2...12))
    var ingredients: [String]

    @Guide(description: "One short cooking step", .count(2...6))
    var steps: [String]
}

@Generable(description: "The food visible in a photo")
struct PantryScan {
    @Guide(description: "One food item, such as eggs", .count(1...20))
    var items: [String]
}

@Generable
struct DinnerPick {
    @Guide(description: "The exact name of a listed recipe")
    var recipeName: String

    @Guide(description: "One appealing detail about the dish, in a few words")
    var reason: String
}

@Generable(description: "The chosen dinners")
struct DinnerPicks {
    @Guide(.count(1...7))
    var dinners: [DinnerPick]
}

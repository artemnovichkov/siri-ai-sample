import AppIntents
import Foundation

// Generable entities: plain values Siri's model writes itself from what the person said. No query
// runs, so `perform()` has to validate them. The descriptions are what the model writes from, so
// they state the format or unit and give an example.

@AppEntity(.generable)
struct IngredientDraft {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Ingredient"

    @Property(title: "Name", description: "The ingredient by itself, such as eggs or canned tomatoes")
    var name: String

    @Property(title: "Amount", description: "How much is needed, as a number, such as 3 or 0.5. Leave empty when the person didn't say.")
    var amount: Double?

    @Property(title: "Unit", description: "The unit for the amount, such as g, ml, tbsp, or cups. Leave empty for countable things like 3 eggs.")
    var unit: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(formatted)")
    }

    var formatted: String {
        guard let amount else { return name }
        let number = amount.formatted(.number.precision(.fractionLength(0...2)))
        return [number, unit, name].compactMap { $0 }.joined(separator: " ")
    }

    init() {}
}

@AppEntity(.generable)
struct RecipeDraft {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Recipe Draft"

    @Property(title: "Name", description: "A short name for the dish, such as Sunday Omelette")
    var name: String

    @Property(title: "Summary", description: "One sentence on what the dish is. Write one if the person didn't.")
    var summary: String

    @Property(title: "Cuisine", description: "The culinary tradition the dish belongs to. Use other when none fits.")
    var cuisine: Cuisine

    @Property(title: "Cook Time", description: "Total time from start to serving in minutes, such as 30")
    var minutes: Int

    @Property(title: "Servings", description: "How many people the amounts feed, such as 2")
    var servings: Int

    @Property(title: "Ingredients", description: "Everything the dish needs, one entry per ingredient")
    var ingredients: [IngredientDraft]

    @Property(title: "Instructions", description: "The cooking method as short sentences, in order")
    var instructions: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(ingredients.count) ingredients")
    }

    init() {}
}

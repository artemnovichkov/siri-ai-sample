import Foundation
import SwiftData

// Identifiers are stable strings on purpose. Siri, donations, and saved shortcuts keep references
// to them, so a UUID() generated at launch would break every saved reference.

@Model
final class Recipe {
    @Attribute(.unique) var id: String
    var name: String
    var summary: String
    var cuisineRawValue: String
    var minutes: Int
    var servings: Int
    var ingredients: [String]
    var instructions: String
    var familyNotes: String
    var revision: Int

    var cuisine: Cuisine { Cuisine(rawValue: cuisineRawValue) ?? .other }

    init(
        id: String,
        name: String,
        summary: String,
        cuisine: Cuisine,
        minutes: Int,
        servings: Int,
        ingredients: [String],
        instructions: String,
        familyNotes: String = "",
        revision: Int = 1
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.cuisineRawValue = cuisine.rawValue
        self.minutes = minutes
        self.servings = servings
        self.ingredients = ingredients
        self.instructions = instructions
        self.familyNotes = familyNotes
        self.revision = revision
    }
}

@Model
final class MealPlanEntry {
    /// One meal per slot, so the identifier is derived from the day and the meal.
    @Attribute(.unique) var id: String
    var date: Date
    var mealRawValue: String
    var recipeID: String

    var meal: MealType { MealType(rawValue: mealRawValue) ?? .dinner }

    init(id: String, date: Date, meal: MealType, recipeID: String) {
        self.id = id
        self.date = date
        self.mealRawValue = meal.rawValue
        self.recipeID = recipeID
    }
}

@Model
final class ShoppingList {
    @Attribute(.unique) var id: String
    var name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

@Model
final class ShoppingItem {
    @Attribute(.unique) var id: String
    var listID: String
    var name: String
    var isChecked: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString, listID: String, name: String, isChecked: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.listID = listID
        self.name = name
        self.isChecked = isChecked
        self.createdAt = createdAt
    }
}

@Model
final class JournalEntry {
    @Attribute(.unique) var id: String
    var title: String?
    var message: String
    var date: Date

    init(id: String = UUID().uuidString, title: String?, message: String, date: Date) {
        self.id = id
        self.title = title
        self.message = message
        self.date = date
    }
}

import AppIntents
import CoreLocation
import Foundation
import SwiftUI

/// The parameter is a generable entity, so Siri writes the whole recipe from the conversation.
@AppIntent(.tool)
struct CreateRecipeIntent {
    static let title: LocalizedStringResource = "Create Recipe"
    static let description = IntentDescription(
        "Saves a new recipe in Larder from what the person described, including its ingredients and method.",
        searchKeywords: ["add recipe", "save recipe", "new dish"]
    )

    @Parameter(
        title: "Recipe",
        description: "The new recipe. For example, Sunday Omelette, 10 minutes, serves 2, with 3 eggs and 50 g cheese."
    )
    var draft: RecipeDraft

    @Dependency private var store: LarderStore

    @MainActor
    func perform() async throws -> some ReturnsValue<RecipeEntity> & ProvidesDialog & ShowsSnippetIntent {
        // No query checked this value. It came straight from the model, so validate it here.
        guard !draft.ingredients.isEmpty else { throw LarderError.emptyIngredients }
        guard draft.minutes > 0 else { throw LarderError.invalidCookTime }

        let recipe = try store.createRecipe(
            name: draft.name,
            summary: draft.summary,
            cuisine: draft.cuisine,
            minutes: draft.minutes,
            servings: max(draft.servings, 1),
            ingredients: draft.ingredients.map(\.formatted),
            instructions: draft.instructions
        )
        // Without this, Siri can't find the new recipe in later requests.
        try await store.reindex(recipeID: recipe.id)

        let entity = RecipeEntity(recipe)
        return .result(
            value: entity,
            dialog: "Saved \(entity.name) in Larder.",
            snippetIntent: RecipeCardSnippetIntent(recipe: entity)
        )
    }
}

/// Shows the app's own branded card in Siri's response.
@AppIntent(.tool)
struct ShowRecipeCardIntent {
    static let title: LocalizedStringResource = "Show Recipe Card"
    static let description = IntentDescription(
        "Shows a card with a recipe's cook time and ingredients, with a button that adds them to the shopping list. Changes nothing by itself.",
        searchKeywords: ["ingredients", "how long", "what's in"]
    )

    @Parameter(title: "Recipe", description: "The recipe to show")
    var recipe: RecipeEntity

    func perform() async throws -> some ReturnsValue<RecipeEntity> & ProvidesDialog & ShowsSnippetIntent {
        .result(
            value: recipe,
            dialog: "\(recipe.name) takes \(recipe.minutes) minutes.",
            snippetIntent: RecipeCardSnippetIntent(recipe: recipe)
        )
    }
}

/// A journaling schema is Shortcuts-only by default. `.tool` brings it to Siri, and the parameters
/// and result still have to match the schema. Domains like `messages` or `notes` are already handled
/// by Siri, where this combination is a build error.
@AppIntent(.tool, schema: .journal.createEntry)
struct LogCookedMealIntent {
    var title: String?
    var message: AttributedString
    var mediaItems: [IntentFile]
    var entryDate: Date?
    var location: CLPlacemark?

    @Dependency private var store: LarderStore

    @MainActor
    func perform() async throws -> some ReturnsValue<JournalEntryEntity> {
        let entry = try store.addJournalEntry(
            title: title,
            message: String(message.characters),
            date: entryDate ?? .now
        )
        return .result(value: JournalEntryEntity(entry))
    }
}

/// Not a tool: this exists so tapping a recipe in Spotlight opens it in the app. Tools have to work
/// whenever they're called, including while the app isn't on screen.
struct OpenRecipeIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Recipe"
    static let description = IntentDescription("Opens a recipe in Larder.")

    @Parameter(title: "Recipe", description: "The recipe to open")
    var target: RecipeEntity

    @Dependency private var store: LarderStore

    @MainActor
    func perform() async throws -> some IntentResult {
        store.open(recipeID: target.id)
        return .result()
    }
}

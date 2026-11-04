import AppIntents
import CoreSpotlight
import CoreTransferable
import Foundation

/// An app-owned entity. Siri finds it through Spotlight (`IndexedEntity`), which doesn't launch the
/// app and works even when the request doesn't name it. Tools then take it as a parameter, so there's
/// deliberately no "search recipes" tool.
struct RecipeEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Recipe"
    static let defaultQuery = RecipeQuery()

    let id: String

    @Property(
        title: "Name",
        description: "The recipe's name, such as Shakshuka",
        indexingKey: \.displayName
    )
    var name: String

    @Property(
        title: "Summary",
        description: "One sentence on what the dish is and how it tastes",
        indexingKey: \.contentDescription
    )
    var summary: String

    @Property(title: "Cuisine", description: "The culinary tradition the dish belongs to")
    var cuisine: Cuisine

    @Property(title: "Cook Time", description: "Total time from start to serving in minutes, such as 30")
    var minutes: Int

    @Property(title: "Servings", description: "How many people the ingredient amounts feed")
    var servings: Int

    @Property(
        title: "Ingredients",
        description: "Each ingredient with its amount, such as 400 g canned tomatoes"
    )
    var ingredients: [String]

    // Authentication: Siri asks to unlock the device before it reads this aloud. Household health
    // details are the kind of thing a passerby shouldn't hear from a locked phone.
    @Property(
        title: "Family Notes",
        description: "The household's private notes on allergies and preferences for this dish",
        authenticationPolicy: .requiresLocalDeviceAuthentication
    )
    var familyNotes: String

    // Internal: visible to the app and its extensions, never to Siri, Shortcuts, or Spotlight.
    @Property(title: "Revision", description: "How many times the app has saved this recipe", visibility: .internal)
    var revision: Int

    // Computed: derived from other values, evaluated whenever the entity materializes.
    @ComputedProperty(title: "Quick", description: "Whether the dish takes 30 minutes or less")
    var isQuick: Bool { minutes <= 30 }

    // Deferred: fetched only when something reads it, which keeps entity creation cheap.
    @DeferredProperty(title: "Instructions", description: "The step-by-step cooking method")
    var instructions: String {
        get async throws {
            let id = id
            return await MainActor.run { LarderStore.shared.recipe(id: id)?.instructions ?? "" }
        }
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(cuisine.title) · \(minutes) min"
        )
    }

    init(
        id: String,
        name: String,
        summary: String,
        cuisine: Cuisine,
        minutes: Int,
        servings: Int,
        ingredients: [String],
        familyNotes: String,
        revision: Int
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.cuisine = cuisine
        self.minutes = minutes
        self.servings = servings
        self.ingredients = ingredients
        self.familyNotes = familyNotes
        self.revision = revision
    }

    @MainActor
    init(_ recipe: Recipe) {
        self.init(
            id: recipe.id,
            name: recipe.name,
            summary: recipe.summary,
            cuisine: recipe.cuisine,
            minutes: recipe.minutes,
            servings: recipe.servings,
            ingredients: recipe.ingredients,
            familyNotes: recipe.familyNotes,
            revision: recipe.revision
        )
    }
}

// Transferable: lets Siri hand a recipe to another app, as in "email the shakshuka recipe to Sam."
// The family notes stay out of the exported text on purpose.
extension RecipeEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.shareText)
    }

    var shareText: String {
        """
        \(name) (\(minutes) min, serves \(servings))
        \(summary)

        Ingredients:
        \(ingredients.map { "- \($0)" }.joined(separator: "\n"))
        """
    }
}

/// `entities(for:)` is what every non-transient entity needs. The string query and suggestions don't
/// help Siri's tools, but the Shortcuts app and its parameter pickers use them.
struct RecipeQuery: EntityStringQuery, IndexedEntityQuery {
    @Dependency private var store: LarderStore

    @MainActor
    func entities(for identifiers: [RecipeEntity.ID]) async throws -> [RecipeEntity] {
        store.recipes(ids: identifiers).map(RecipeEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [RecipeEntity] {
        store.allRecipes()
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(RecipeEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [RecipeEntity] {
        store.allRecipes().map(RecipeEntity.init)
    }

    // The system calls these when it decides the Spotlight index needs a refresh. They stay nonisolated
    // because CSSearchableIndexDescription isn't Sendable, and only the store call hops to the main actor.
    func reindexEntities(
        for identifiers: [RecipeEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        for id in identifiers {
            try await store.reindex(recipeID: id)
        }
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        try await store.reindexRecipes()
    }
}

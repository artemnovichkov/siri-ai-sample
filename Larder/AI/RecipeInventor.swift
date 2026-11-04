import CoreImage
import FoundationModels
import Observation

/// Streams a structured recipe, and reads ingredients from a photo.
@MainActor
@Observable
final class RecipeInventor {
    private(set) var idea: RecipeIdea.PartiallyGenerated?
    private(set) var isGenerating = false
    private(set) var isScanning = false
    var errorMessage: String?

    /// `true` once the stream has delivered the whole value, so it's safe to save.
    private(set) var finishedIdea: RecipeIdea?

    func invent(from ingredients: String) async {
        isGenerating = true
        errorMessage = nil
        idea = nil
        finishedIdea = nil
        defer { isGenerating = false }

        // A new session per recipe, because earlier ideas shouldn't use up the context window.
        let session = LanguageModelSession(instructions: ChefPrompts.inventInstructions)
        do {
            let stream = session.streamResponse(
                to: ChefPrompts.invent(ingredients: ingredients),
                generating: RecipeIdea.self
            )
            for try await snapshot in stream {
                idea = snapshot.content
            }
            finishedIdea = try await stream.collect().content
        } catch {
            errorMessage = ChefModel.message(for: error)
        }
    }

    /// Multimodal prompt. The framework scales and converts the image, so it needs no preprocessing.
    func scanIngredients(in image: CIImage) async -> [String] {
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }

        let session = LanguageModelSession()
        do {
            let response = try await session.respond(generating: PantryScan.self) {
                "List all food items in this photo."
                Attachment(image)
            }
            return response.content.items
        } catch {
            errorMessage = ChefModel.message(for: error)
            return []
        }
    }

    /// Saves through the same store method as the Create Recipe tool, and indexes the result so Siri
    /// can find it.
    func save(_ idea: RecipeIdea, in store: LarderStore) async throws -> Recipe {
        let recipe = try store.createRecipe(
            name: idea.name,
            summary: idea.summary,
            cuisine: idea.cuisine.cuisine,
            minutes: idea.minutes,
            servings: idea.servings,
            ingredients: idea.ingredients,
            instructions: idea.steps.joined(separator: " ")
        )
        try await store.reindex(recipeID: recipe.id)
        return recipe
    }
}

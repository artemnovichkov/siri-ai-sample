import AppIntents
import SwiftUI

/// The system can re-run this on any redraw, so `perform()` only reads. Mutations belong in the
/// separate intent the card's button runs.
struct RecipeCardSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Recipe Card"
    static let isDiscoverable = false

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity

    init() {}

    init(recipe: RecipeEntity) {
        self.recipe = recipe
    }

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: RecipeCardView(recipe: recipe))
    }
}

struct RecipeCardView: View {
    let recipe: RecipeEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name).font(.title3.bold())
                Text("\(recipe.cuisine.title) · \(recipe.minutes) min · serves \(recipe.servings)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(recipe.ingredients.joined(separator: ", "))
                .font(.subheadline)
                .lineLimit(3)
            // Controls in a snippet run intents. Closures in a snippet run nothing.
            Button(intent: AddRecipeIngredientsIntent(recipe: recipe)) {
                Label("Add to Groceries", systemImage: "cart.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

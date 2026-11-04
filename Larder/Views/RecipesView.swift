import AppIntents
import SwiftData
import SwiftUI

/// A list of recipes that a shelf or a category opens.
struct RecipesView: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    let collection: RecipeCollection
    @State private var selection: String?

    var body: some View {
        List(collection.recipes(from: recipes), selection: $selection) { recipe in
            NavigationLink(value: RecipeRoute(id: recipe.id)) {
                RecipeRow(recipe: recipe)
            }
            .alignmentGuide(.listRowSeparatorLeading) { _ in 66 }
        }
        .listStyle(.plain)
        // Several items on screen: annotate each row so "the second one" maps to the right entity.
        .appEntityIdentifier(forSelectionType: String.self) { id in
            EntityIdentifier(for: RecipeEntity.self, identifier: id)
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

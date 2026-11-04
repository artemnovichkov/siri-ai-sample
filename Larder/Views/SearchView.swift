import SwiftData
import SwiftUI

struct SearchView: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 14)]

    private var results: [Recipe] {
        let term = query.trimmingCharacters(in: .whitespaces)
        return recipes.filter { recipe in
            recipe.name.localizedStandardContains(term)
                || recipe.summary.localizedStandardContains(term)
                || recipe.cuisine.title.localizedStandardContains(term)
                || recipe.ingredients.contains { $0.localizedStandardContains(term) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    browse
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results) { recipe in
                        NavigationLink(value: RecipeRoute(id: recipe.id)) {
                            RecipeRow(recipe: recipe)
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 66 }
                        .recipeEntity(recipe.id)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .recipeDestinations()
        }
        // On the stack rather than inside it, so the system can dock the field at the bottom.
        .searchable(text: $query, prompt: "Recipes and ingredients")
    }

    private var browse: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ShelfHeader(title: "Browse by Cuisine")
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Cuisine.allCases, id: \.self) { CuisineTile(cuisine: $0) }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }
}

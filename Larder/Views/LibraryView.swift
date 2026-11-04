import SwiftData
import SwiftUI

struct LibraryView: View {
    private enum Route: Hashable { case journal, examples }

    @Query(sort: \Recipe.name) private var recipes: [Recipe]

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(spacing: 0) {
                        NavigationLink(value: RecipeCollection.all) {
                            LibraryRow(title: "Recipes", symbol: "fork.knife", count: recipes.count)
                        }
                        Divider().padding(.leading, 56)
                        NavigationLink(value: Route.journal) {
                            LibraryRow(title: "Cooking Journal", symbol: "book.closed.fill")
                        }
                        Divider().padding(.leading, 56)
                        NavigationLink(value: Route.examples) {
                            LibraryRow(title: "AI Examples", symbol: "sparkles")
                        }
                    }
                    .buttonStyle(.plain)

                    let family = RecipeCollection.family.recipes(from: recipes)
                    if !family.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ShelfHeader(title: RecipeCollection.family.title)
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                                ForEach(family) { RecipeCoverCard(recipe: $0) }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Library")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .journal: JournalView()
                case .examples: SiriExamplesView()
                }
            }
            .recipeDestinations()
        }
    }
}

private struct LibraryRow: View {
    let title: String
    let symbol: String
    var count: Int?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 26)
                .accessibilityHidden(true)
            Text(title).font(.title3)
            Spacer()
            if let count {
                Text(count, format: .number).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.forward")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

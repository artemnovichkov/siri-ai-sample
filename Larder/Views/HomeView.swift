import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(LarderStore.self) private var store
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query private var entries: [MealPlanEntry]
    @State private var isInventing = false

    private var tonight: Recipe? {
        let dinner = entries.first { Calendar.current.isDateInToday($0.date) && $0.meal == .dinner }
        return recipes.first { $0.id == dinner?.recipeID }
    }

    /// Tonight's dinner first, then a selection that changes daily but stays put during the day.
    private var picks: [Recipe] {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        let rotated = recipes
            .filter { $0.id != tonight?.id }
            .sorted { ArtworkPalette(id: "\($0.id)\(day)", cuisine: $0.cuisine).seed < ArtworkPalette(id: "\($1.id)\(day)", cuisine: $1.cuisine).seed }
        return Array(([tonight].compactMap { $0 } + rotated).prefix(5))
    }

    private func eyebrow(for recipe: Recipe) -> String {
        if recipe.id == tonight?.id { return "Tonight's Dinner" }
        if !recipe.familyNotes.isEmpty { return "Family Favorite" }
        if recipe.minutes <= 30 { return "Ready in \(recipe.duration)" }
        return "Worth the Time"
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $store.homePath) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 30) {
                    if !picks.isEmpty {
                        section(title: "Top Picks for You") {
                            Shelf {
                                ForEach(picks) { recipe in
                                    RecipePosterCard(recipe: recipe, eyebrow: eyebrow(for: recipe))
                                        .containerRelativeFrame(.horizontal) { width, _ in min(width * 0.72, 340) }
                                }
                            }
                        }
                    }

                    InventBanner { isInventing = true }
                        .padding(.horizontal, 16)

                    shelf(.quick)
                    shelf(.unhurried)
                    shelf(.family)

                    section(title: "Browse by Cuisine") {
                        Shelf {
                            ForEach(cuisines, id: \.self) { cuisine in
                                CuisineTile(cuisine: cuisine)
                                    .containerRelativeFrame(.horizontal) { width, _ in min(width * 0.46, 220) }
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Home")
            .toolbar {
                Button("Invent a Recipe", systemImage: "sparkles") { isInventing = true }
            }
            .sheet(isPresented: $isInventing) { InventRecipeView() }
            .recipeDestinations()
        }
    }

    private var cuisines: [Cuisine] {
        Cuisine.allCases.filter { cuisine in recipes.contains { $0.cuisine == cuisine } }
    }

    @ViewBuilder
    private func shelf(_ collection: RecipeCollection) -> some View {
        let items = collection.recipes(from: recipes)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ShelfHeader(title: collection.title, collection: collection)
                Shelf {
                    ForEach(items) { recipe in
                        RecipeCoverCard(recipe: recipe)
                            .containerRelativeFrame(.horizontal) { width, _ in min(width * 0.44, 210) }
                    }
                }
            }
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ShelfHeader(title: title)
            content()
        }
    }
}

private struct InventBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title.weight(.semibold))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invent a Recipe").font(.headline)
                    Text("Tell Chef what's in your kitchen.")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.subheadline.weight(.bold))
                    .opacity(0.7)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .padding(16)
            .background {
                ArtworkGradient(palette: ArtworkPalette(id: "chef", cuisine: .other))
                    .overlay(.black.opacity(0.12))
            }
            .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(CardButtonStyle())
    }
}

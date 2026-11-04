import AppIntents
import SwiftUI

extension View {
    /// Tells Siri which recipe an item on screen shows, so "the second one" resolves to the right entity.
    func recipeEntity(_ id: String) -> some View {
        appEntityIdentifier(EntityIdentifier(for: RecipeEntity.self, identifier: id))
    }

    /// Every tab pushes recipes and collections, so each navigation stack registers the same screens.
    func recipeDestinations() -> some View {
        navigationDestination(for: RecipeRoute.self) { RecipeDestination(id: $0.id) }
            .navigationDestination(for: RecipeCollection.self) { RecipesView(collection: $0) }
    }
}

private struct RecipeDestination: View {
    @Environment(LarderStore.self) private var store
    let id: String

    var body: some View {
        if let recipe = store.recipe(id: id) {
            RecipeDetailView(recipe: recipe)
        } else {
            ContentUnavailableView("Recipe Not Found", systemImage: "fork.knife")
        }
    }
}

/// Dims on touch, because a plain button style gives no feedback on a large card.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct ShelfHeader: View {
    let title: String
    var collection: RecipeCollection?

    var body: some View {
        Group {
            if let collection {
                NavigationLink(value: collection) {
                    HStack(spacing: 4) {
                        Text(title)
                        Image(systemName: "chevron.forward")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(title)
            }
        }
        .font(.title3.bold())
        .accessibilityAddTraits(.isHeader)
        .padding(.horizontal, 16)
    }
}

/// A horizontally scrolling row that snaps to its items and lets their shadows spill out.
struct Shelf<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 14) {
                content()
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

struct RecipeCoverCard: View {
    let recipe: Recipe

    var body: some View {
        NavigationLink(value: RecipeRoute(id: recipe.id)) {
            VStack(alignment: .leading, spacing: 8) {
                RecipeArtwork(recipe)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
                VStack(alignment: .leading, spacing: 1) {
                    Text(recipe.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(recipe.byline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(CardButtonStyle())
        .recipeEntity(recipe.id)
    }
}

/// A tall feature card, like the top row of a home screen in Apple Music.
struct RecipePosterCard: View {
    let recipe: Recipe
    let eyebrow: String

    var body: some View {
        NavigationLink(value: RecipeRoute(id: recipe.id)) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack {
                    ArtworkGradient(palette: ArtworkPalette(id: recipe.id, cuisine: recipe.cuisine))
                    LinearGradient(colors: [.clear, .black.opacity(0.32)], startPoint: .center, endPoint: .bottom)
                    PosterPlate(recipe: recipe, width: width)
                    Wordmark(size: width * 0.05)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(width * 0.065)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.name)
                            .font(.system(size: width * 0.17, weight: .bold))
                            .lineLimit(3)
                            .minimumScaleFactor(0.6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(eyebrow).opacity(0.75)
                            Text(recipe.summary).lineLimit(2)
                        }
                        .font(.subheadline.weight(.medium))
                        // The card has a fixed shape, so a larger caption would push the title onto the symbol.
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(width * 0.065)
                }
                .clipShape(.rect(cornerRadius: 18))
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .shadow(color: .black.opacity(0.18), radius: 16, y: 10)
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityElement(children: .combine)
        .recipeEntity(recipe.id)
    }
}

private struct PosterPlate: View {
    let recipe: Recipe
    let width: CGFloat

    var body: some View {
        ZStack {
            ForEach(1...4, id: \.self) { ring in
                Circle()
                    .stroke(.white.opacity(0.11), lineWidth: width * 0.055)
                    .frame(width: width * CGFloat(ring) * 0.4, height: width * CGFloat(ring) * 0.4)
            }
            Image(systemName: FoodSymbol.name(forDish: recipe.name, ingredients: recipe.ingredients))
                .font(.system(size: width * 0.17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
        .position(x: width * 0.68, y: width * 0.44)
        .accessibilityHidden(true)
    }
}

struct CuisineTile: View {
    let cuisine: Cuisine

    var body: some View {
        NavigationLink(value: RecipeCollection.cuisine(cuisine)) {
            ZStack(alignment: .bottomLeading) {
                ArtworkGradient(palette: ArtworkPalette(id: cuisine.rawValue, cuisine: cuisine))
                Image(systemName: cuisine.symbol)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.28))
                    .rotationEffect(.degrees(14))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(12)
                    .accessibilityHidden(true)
                Text(cuisine.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
            }
            .aspectRatio(1.55, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(CardButtonStyle())
    }
}

struct RecipeRow: View {
    let recipe: Recipe
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            RecipeArtwork(recipe, style: .thumbnail, cornerRadius: 8)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .lineLimit(1)
                Text(subtitle ?? recipe.byline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A brief confirmation that floats over the content and goes away by itself.
struct ConfirmationHUD: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassEffect()
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// The input bar along the bottom of Chef's screens.
struct ChefComposer<Leading: View>: View {
    let prompt: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var isBusy = false
    /// Preferences are optional, while a question or a list of ingredients isn't.
    var allowsEmpty = false
    let send: () -> Void
    @ViewBuilder var leading: () -> Leading

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            leading()
            TextField(prompt, text: $text, axis: axis)
                .lineLimit(1...4)
                .padding(.vertical, 8)
                .padding(.leading, Leading.self == EmptyView.self ? 8 : 0)
                .onSubmit(send)
                .submitLabel(.send)
            Button("Send", systemImage: "arrow.up", action: send)
                .labelStyle(.iconOnly)
                .fontWeight(.bold)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(.white)
                .foregroundStyle(.black)
                .disabled((isEmpty && !allowsEmpty) || isBusy)
        }
        .padding(8)
        .glassEffect(in: .rect(cornerRadius: 26))
    }
}

extension ChefComposer where Leading == EmptyView {
    init(prompt: String, text: Binding<String>, axis: Axis = .horizontal, isBusy: Bool = false, allowsEmpty: Bool = false, send: @escaping () -> Void) {
        self.init(prompt: prompt, text: text, axis: axis, isBusy: isBusy, allowsEmpty: allowsEmpty, send: send) { EmptyView() }
    }
}

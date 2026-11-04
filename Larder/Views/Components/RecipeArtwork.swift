import SwiftUI

/// Recipes have no photos, and Chef can invent new ones at any time, so every recipe gets generated
/// cover art. It's derived from the recipe's ID, so a recipe keeps its cover across launches.
struct ArtworkPalette {
    let colors: [Color]
    let seed: UInt64

    init(id: String, cuisine: Cuisine) {
        // `hashValue` changes on every launch, so it can't be used here.
        seed = id.utf8.reduce(5381) { ($0 &* 33) &+ UInt64($1) }
        let options = Self.options(for: cuisine)
        colors = options[Int(seed % UInt64(options.count))].map { Color(hex: $0) }
    }

    /// Top is the brightest, and bottom stays deep enough to carry white text.
    private static func options(for cuisine: Cuisine) -> [[UInt32]] {
        switch cuisine {
        case .italian:
            [[0xFF5A36, 0xE11D3F, 0xB5122F, 0x7F0D2A], [0x22A565, 0x0E7C55, 0xC8263C, 0x7A1230]]
        case .mexican:
            [[0x17C3A5, 0x0E8F8C, 0xE8622A, 0x8E1B3F], [0xA3C72C, 0x1E9A5B, 0x0F6E86, 0x0D3F5F]]
        case .thai:
            [[0xFF8A3D, 0xF0326E, 0xB3178F, 0x5B1A9C], [0xFFB02E, 0xE5484D, 0xA61F7A, 0x571B7E]]
        case .middleEastern:
            [[0xFFB22E, 0xEE6A1F, 0xC42B2B, 0x7E1D2F], [0xF7C948, 0xD9722A, 0x9A3412, 0x5A1E12]]
        case .other:
            [[0x38BDF8, 0x4F6BF5, 0x7C3AED, 0x3B1E9E], [0xF472B6, 0xA855F7, 0x4F46E5, 0x1E2A8A]]
        }
    }

    var points: [SIMD2<Float>] {
        let x = 0.3 + Float(seed % 40) / 100
        let y = 0.3 + Float((seed >> 8) % 40) / 100
        return [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [x, y], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
        ]
    }

    var meshColors: [Color] {
        let (a, b, c, d) = (colors[0], colors[1], colors[2], colors[3])
        return seed % 2 == 0 ? [a, a, b, b, a, c, c, d, d] : [b, a, a, c, a, b, d, d, c]
    }
}

struct ArtworkGradient: View {
    let palette: ArtworkPalette

    var body: some View {
        MeshGradient(width: 3, height: 3, points: palette.points, colors: palette.meshColors)
    }
}

/// The same colors, darkened for white text across a whole screen.
struct ArtworkBackground: View {
    let palette: ArtworkPalette

    var body: some View {
        ArtworkGradient(palette: palette)
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.28), .black.opacity(0.58), .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
    }
}

/// Concentric rings that read as a plate, with the dish's symbol at the center.
private struct PlateMotif: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(1...4, id: \.self) { ring in
                Circle()
                    .stroke(.white.opacity(0.11), lineWidth: size * 0.05)
                    .frame(width: size * CGFloat(ring) * 0.36, height: size * CGFloat(ring) * 0.36)
            }
            Image(systemName: symbol)
                .font(.system(size: size * 0.17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
    }
}

struct Wordmark: View {
    let size: CGFloat

    var body: some View {
        HStack(spacing: size * 0.25) {
            Image(systemName: "fork.knife")
            Text(verbatim: "larder")
        }
        .font(.system(size: size, weight: .bold))
        .foregroundStyle(.white.opacity(0.95))
    }
}

struct RecipeArtwork: View {
    enum Style { case thumbnail, cover }

    let palette: ArtworkPalette
    let name: String
    let symbol: String
    var style: Style = .cover
    var cornerRadius: CGFloat = 12

    init(_ recipe: Recipe, style: Style = .cover, cornerRadius: CGFloat = 12) {
        self.init(
            id: recipe.id,
            name: recipe.name,
            cuisine: recipe.cuisine,
            ingredients: recipe.ingredients,
            style: style,
            cornerRadius: cornerRadius
        )
    }

    init(id: String, name: String, cuisine: Cuisine, ingredients: [String], style: Style = .cover, cornerRadius: CGFloat = 12) {
        palette = ArtworkPalette(id: id, cuisine: cuisine)
        self.name = name
        symbol = FoodSymbol.name(forDish: name, ingredients: ingredients)
        self.style = style
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                ArtworkGradient(palette: palette)
                switch style {
                case .thumbnail:
                    Image(systemName: symbol)
                        .font(.system(size: width * 0.44, weight: .semibold))
                        .foregroundStyle(.white)
                case .cover:
                    PlateMotif(symbol: symbol, size: width * 1.05)
                        .position(x: width * 0.72, y: width * 0.36)
                    Wordmark(size: width * 0.06)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(width * 0.07)
                    Text(name)
                        .font(.system(size: width * 0.125, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(width * 0.07)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
    }
}

enum FoodSymbol {
    /// Checked in order, so a more specific dish wins over an ingredient it shares with others.
    private static let rules: [(keywords: [String], symbol: String)] = [
        (["fish", "salmon", "tuna", "shrimp"], "fish.fill"),
        (["pizza", "dough", "bread", "focaccia"], "oven.fill"),
        (["soup", "stew", "broth", "lentil", "stock"], "mug.fill"),
        (["noodle", "ramen", "pasta", "spaghetti"], "takeoutbag.and.cup.and.straw.fill"),
        (["oats", "granola", "yogurt"], "cup.and.saucer.fill"),
        (["cake", "cookie", "brownie"], "birthday.cake.fill"),
        (["salad", "spinach", "kale"], "leaf.fill"),
        (["carrot"], "carrot.fill"),
        (["egg"], "frying.pan.fill"),
    ]

    static func name(forDish name: String, ingredients: [String]) -> String {
        let dish = name.lowercased()
        // Fish sauce doesn't make a dish about fish.
        let pantry = ingredients.joined(separator: " ").lowercased().replacing("fish sauce", with: "")
        for text in [dish, pantry] {
            if let rule = rules.first(where: { $0.keywords.contains(where: text.contains) }) {
                return rule.symbol
            }
        }
        return "fork.knife"
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Cuisine {
    var symbol: String {
        switch self {
        case .italian: "wineglass.fill"
        case .mexican: "flame.fill"
        case .thai: "leaf.fill"
        case .middleEastern: "sun.max.fill"
        case .other: "fork.knife"
        }
    }
}

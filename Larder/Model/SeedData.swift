import Foundation

enum SeedData {
    static let defaultListID = "groceries"

    static func recipes() -> [Recipe] {
        [
            Recipe(
                id: "shakshuka",
                name: "Shakshuka",
                summary: "Eggs poached in spiced tomato and pepper sauce.",
                cuisine: .middleEastern,
                minutes: 30,
                servings: 2,
                ingredients: ["4 eggs", "400 g canned tomatoes", "1 red bell pepper", "1 onion", "2 cloves garlic", "1 tsp cumin", "1 tsp paprika"],
                instructions: "Soften the onion and pepper. Add garlic and spices. Add tomatoes and simmer for 10 minutes. Make wells, crack in the eggs, cover, and cook until the whites set.",
                familyNotes: "Sam can't have chili, so keep the paprika sweet."
            ),
            Recipe(
                id: "margherita-pizza",
                name: "Margherita Pizza",
                summary: "Classic pizza with tomato, mozzarella, and basil.",
                cuisine: .italian,
                minutes: 90,
                servings: 4,
                ingredients: ["500 g pizza dough", "200 g crushed tomatoes", "250 g mozzarella", "1 bunch basil", "2 tbsp olive oil"],
                instructions: "Stretch the dough. Spread the tomatoes and tear over the mozzarella. Bake at the highest temperature until blistered. Finish with basil and oil."
            ),
            Recipe(
                id: "pad-thai",
                name: "Pad Thai",
                summary: "Stir-fried rice noodles with tamarind, egg, and peanuts.",
                cuisine: .thai,
                minutes: 25,
                servings: 2,
                ingredients: ["200 g rice noodles", "2 eggs", "200 g firm tofu", "3 tbsp tamarind paste", "2 tbsp fish sauce", "100 g bean sprouts", "50 g peanuts"],
                instructions: "Soak the noodles. Fry the tofu, then scramble the eggs. Add noodles and sauce and toss until absorbed. Finish with sprouts and peanuts.",
                familyNotes: "Leave peanuts on the side for Alex."
            ),
            Recipe(
                id: "lentil-soup",
                name: "Red Lentil Soup",
                summary: "Silky weeknight soup with lemon and cumin.",
                cuisine: .middleEastern,
                minutes: 35,
                servings: 4,
                ingredients: ["300 g red lentils", "1 onion", "2 carrots", "1 l vegetable stock", "1 lemon", "1 tsp cumin"],
                instructions: "Soften the onion and carrots. Add lentils, cumin, and stock, then simmer for 20 minutes. Blend and sharpen with lemon."
            ),
            Recipe(
                id: "fish-tacos",
                name: "Fish Tacos",
                summary: "Crisp white fish with cabbage slaw and lime crema.",
                cuisine: .mexican,
                minutes: 40,
                servings: 3,
                ingredients: ["500 g white fish", "12 corn tortillas", "1/4 red cabbage", "150 g sour cream", "2 limes", "1 bunch cilantro"],
                instructions: "Season and pan-fry the fish. Shred the cabbage and dress it with lime. Stir lime into the sour cream. Warm the tortillas and assemble."
            ),
            Recipe(
                id: "overnight-oats",
                name: "Overnight Oats",
                summary: "No-cook breakfast with oats, yogurt, and berries.",
                cuisine: .other,
                minutes: 5,
                servings: 1,
                ingredients: ["60 g rolled oats", "120 ml milk", "100 g yogurt", "100 g berries", "1 tsp honey"],
                instructions: "Stir everything together in a jar and refrigerate overnight."
            ),
        ]
    }

    static func shoppingLists() -> [ShoppingList] {
        [
            ShoppingList(id: defaultListID, name: "Groceries"),
            ShoppingList(id: "farmers-market", name: "Farmers Market"),
        ]
    }
}

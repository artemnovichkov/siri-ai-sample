import Foundation

// Prompts and scheduling stay free of app state, so they can run against a real model outside the
// app. The on-device model follows simple instructions well, but it doesn't reliably reason about
// constraints: with a list of free days it still filled taken ones and repeated recipes, and when told
// to pick all six of six recipes it ignored "vegetarian". So the model only chooses dishes, it may
// choose fewer, and code handles everything that has to be correct.
enum ChefPrompts {
    static let inventInstructions = """
        You are a home cook who writes simple, reliable recipes. \
        Use the ingredients the person lists, and add only common pantry staples. \
        Never invent unsafe food combinations.
        """

    static func invent(ingredients: String) -> String {
        "Write a recipe using these ingredients: \(ingredients)"
    }

    static let weekInstructions = """
        You choose dinners for a home cook. Choose only from the listed recipes. Choose as many as \
        fit. Leave out any recipe that breaks the person's preferences, and leave out breakfast dishes.
        """

    static func week(recipes: [String], preferences: String) -> String {
        """
        Choose dinners. \(preferences.isEmpty ? "" : "Preferences: \(preferences)")

        Recipes:
        \(recipes.joined(separator: "\n"))
        """
    }

    static func chatInstructions(
        name: String,
        servings: Int,
        minutes: Int,
        ingredients: [String],
        familyNotes: String
    ) -> String {
        let restrictions = familyNotes.isEmpty ? "" : """


            Allergies and restrictions you must always follow, even if the person asks otherwise:
            \(familyNotes)

            Never suggest an ingredient that breaks these restrictions. If the person asks for one, say \
            why you can't and offer a safe alternative.
            """
        return """
            You are a friendly cooking assistant. Answer in two or three sentences. Only call \
            proposeGroceries when the person explicitly asks to buy or add something.

            Recipe: \(name), serves \(servings), \(minutes) minutes.
            Ingredients: \(ingredients.joined(separator: "; "))\(restrictions)
            """
    }
}

/// Puts the longest dishes on the weekend and the shortest on weeknights. Keeps only the first use of
/// each dish, because the model repeats them. `duration` returns nil for a dish that isn't in the app.
enum WeekSchedule {
    static func assign<Dish>(
        picks: [Dish],
        to freeDays: [Date],
        calendar: Calendar = .current,
        key: (Dish) -> String,
        duration: (Dish) -> Int?
    ) -> [(day: Date, dish: Dish)] {
        var seen = Set<String>()
        let dishes = picks
            .filter { duration($0) != nil && seen.insert(key($0).lowercased()).inserted }
            .sorted { (duration($0) ?? 0) > (duration($1) ?? 0) }
        let days = freeDays.sorted { first, second in
            let isFirstWeekend = calendar.isDateInWeekend(first)
            if isFirstWeekend != calendar.isDateInWeekend(second) { return isFirstWeekend }
            return first < second
        }
        return zip(days, dishes)
            .map { (day: $0, dish: $1) }
            .sorted { $0.day < $1.day }
    }
}

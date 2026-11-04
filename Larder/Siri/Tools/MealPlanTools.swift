import AppIntents
import Foundation

/// A tool with a real-world effect. It keeps a confirmation, but only for the destructive path:
/// replacing a planned meal asks first, and adding to an empty slot doesn't.
@AppIntent(.tool)
struct PlanMealIntent {
    static let title: LocalizedStringResource = "Plan Meal"
    static let description = IntentDescription(
        "Puts a recipe on the meal plan for breakfast, lunch, or dinner on a specific day. Asks the person to confirm before replacing a different recipe already planned for that meal.",
        searchKeywords: ["schedule", "menu", "cook"]
    )

    @Parameter(title: "Recipe", description: "The recipe to put on the meal plan")
    var recipe: RecipeEntity

    @Parameter(title: "Date", description: "The day to plan the meal for, in the person's local time zone")
    var date: Date

    @Parameter(title: "Meal", description: "Which meal of the day to plan. Tonight means dinner.")
    var meal: MealType

    @Dependency private var store: LarderStore

    init() {}

    init(recipe: RecipeEntity, date: Date, meal: MealType) {
        self.recipe = recipe
        self.date = date
        self.meal = meal
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<PlannedMealEntity> & ProvidesDialog & ShowsSnippetIntent {
        if let existing = store.plannedMeal(on: date, meal: meal),
           existing.recipeID != recipe.id,
           let current = store.recipe(id: existing.recipeID) {
            // A cancel throws and aborts perform() before anything changes, so don't catch it.
            try await requestConfirmation(
                dialog: "\(current.name) is already planned for \(meal.title.lowercased()) that day. Replace it with \(recipe.name)?"
            )
        }

        let entry = try store.planMeal(recipeID: recipe.id, on: date, meal: meal)
        guard let planned = PlannedMealEntity(entry, store: store) else { throw LarderError.recipeNotFound }

        return .result(
            value: planned,
            dialog: "\(recipe.name) is on the plan for \(meal.title.lowercased()) on \(date.formatted(date: .complete, time: .omitted)).",
            snippetIntent: RecipeCardSnippetIntent(recipe: planned.recipe)
        )
    }
}

/// A read-only tool, so Siri can answer "what's planned for dinner tonight?"
@AppIntent(.tool)
struct GetMealPlanIntent {
    static let title: LocalizedStringResource = "Get Meal Plan"
    static let description = IntentDescription(
        "Returns the meals planned over a range of days, with the recipe for each one. Changes nothing.",
        searchKeywords: ["menu", "dinner", "tonight", "this week"]
    )

    @Parameter(title: "Start Date", description: "The first day to include. Leave empty to start today.")
    var startDate: Date?

    @Parameter(title: "Days", description: "How many days to include, from 1 to 31, such as 1 for a single day or 7 for a week", default: 7)
    var days: Int

    @Dependency private var store: LarderStore

    @MainActor
    func perform() async throws -> some ReturnsValue<[PlannedMealEntity]> & ProvidesDialog {
        guard (1...31).contains(days) else { throw LarderError.invalidDayCount }
        let meals = store.plannedMeals(from: startDate ?? .now, days: days)
            .compactMap { PlannedMealEntity($0, store: store) }
        let dialog: IntentDialog = meals.isEmpty
            ? "Nothing is planned for those days."
            : "There are \(meals.count) meals planned."
        return .result(value: meals, dialog: dialog)
    }
}

@AppIntent(.tool)
struct RemovePlannedMealIntent {
    static let title: LocalizedStringResource = "Remove Planned Meal"
    static let description = IntentDescription(
        "Takes one meal off the meal plan after the person confirms. The recipe itself stays in Larder."
    )

    @Parameter(title: "Planned Meal", description: "The meal to take off the plan")
    var plannedMeal: PlannedMealEntity

    @Dependency private var store: LarderStore

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await requestConfirmation(dialog: "Take \(plannedMeal.recipe.name) off the meal plan?")
        try store.removePlannedMeal(id: plannedMeal.id)
        return .result(dialog: "\(plannedMeal.recipe.name) is off the meal plan.")
    }
}

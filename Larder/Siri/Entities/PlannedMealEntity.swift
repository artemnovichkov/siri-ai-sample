import AppIntents
import Foundation

/// Returned by the planning tools and taken by Remove Planned Meal, so one tool's output can become
/// another tool's input.
struct PlannedMealEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Planned Meal"
    static let defaultQuery = PlannedMealQuery()

    let id: String

    @Property(title: "Date", description: "The day the meal is planned for, in the person's local time zone")
    var date: Date

    @Property(title: "Meal", description: "Which meal of the day this is")
    var meal: MealType

    @Property(title: "Recipe", description: "The recipe planned for this meal")
    var recipe: RecipeEntity

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(recipe.name)",
            subtitle: "\(meal.title), \(date.formatted(date: .abbreviated, time: .omitted))"
        )
    }

    init(id: String, date: Date, meal: MealType, recipe: RecipeEntity) {
        self.id = id
        self.date = date
        self.meal = meal
        self.recipe = recipe
    }

    @MainActor
    init?(_ entry: MealPlanEntry, store: LarderStore) {
        guard let recipe = store.recipe(id: entry.recipeID) else { return nil }
        self.init(id: entry.id, date: entry.date, meal: entry.meal, recipe: RecipeEntity(recipe))
    }
}

struct PlannedMealQuery: EnumerableEntityQuery {
    @Dependency private var store: LarderStore

    @MainActor
    func allEntities() async throws -> [PlannedMealEntity] {
        store.allPlannedMeals().compactMap { PlannedMealEntity($0, store: store) }
    }

    @MainActor
    func entities(for identifiers: [PlannedMealEntity.ID]) async throws -> [PlannedMealEntity] {
        identifiers.compactMap(store.plannedMeal(id:)).compactMap { PlannedMealEntity($0, store: store) }
    }
}

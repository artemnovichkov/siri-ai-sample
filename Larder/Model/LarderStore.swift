import AppIntents
import CoreSpotlight
import Foundation
import Observation
import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case home, plan, shopping, library, search
}

/// The app's single data entry point. The UI and App Intents share it, and every intent's `perform()`
/// stays thin by calling it. `@MainActor` makes the class `Sendable`, which `@Dependency` requires.
@MainActor
@Observable
final class LarderStore {
    static let shared = LarderStore()

    @ObservationIgnored let container: ModelContainer
    var selectedTab: AppTab = .home
    var homePath = NavigationPath()

    struct CookingSession {
        let recipeID: String
        var step = 0
    }

    /// Lives outside the cooking screen, so closing it keeps your place and the bar above the tabs can show it.
    var cooking: CookingSession?
    var isCookingPresented = false

    private var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) {
        let schema = Schema([Recipe.self, MealPlanEntry.self, ShoppingList.self, ShoppingItem.self, JournalEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Couldn't open the Larder store: \(error)")
        }
        seedIfNeeded()
    }

    // MARK: Recipes

    func allRecipes() -> [Recipe] {
        (try? context.fetch(FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    func recipe(id: String) -> Recipe? {
        var descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func recipes(ids: [String]) -> [Recipe] {
        ids.compactMap(recipe(id:))
    }

    func createRecipe(
        name: String,
        summary: String,
        cuisine: Cuisine,
        minutes: Int,
        servings: Int,
        ingredients: [String],
        instructions: String
    ) throws -> Recipe {
        let recipe = Recipe(
            id: uniqueRecipeID(for: name),
            name: name,
            summary: summary,
            cuisine: cuisine,
            minutes: minutes,
            servings: servings,
            ingredients: ingredients,
            instructions: instructions
        )
        context.insert(recipe)
        try context.save()
        return recipe
    }

    private func uniqueRecipeID(for name: String) -> String {
        let slug = name.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "-")
        let base = slug.isEmpty ? "recipe" : slug
        var candidate = base
        var suffix = 2
        while recipe(id: candidate) != nil {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }
        return candidate
    }

    // MARK: Meal plan

    static func entryID(date: Date, meal: MealType) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d-%@", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, meal.rawValue)
    }

    func plannedMeal(id: String) -> MealPlanEntry? {
        var descriptor = FetchDescriptor<MealPlanEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func plannedMeal(on date: Date, meal: MealType) -> MealPlanEntry? {
        plannedMeal(id: Self.entryID(date: date, meal: meal))
    }

    func allPlannedMeals() -> [MealPlanEntry] {
        (try? context.fetch(FetchDescriptor<MealPlanEntry>(sortBy: [SortDescriptor(\.date)]))) ?? []
    }

    func plannedMeals(from start: Date, days: Int) -> [MealPlanEntry] {
        let calendar = Calendar.current
        let lower = calendar.startOfDay(for: start)
        guard let upper = calendar.date(byAdding: .day, value: max(days, 1), to: lower) else { return [] }
        let descriptor = FetchDescriptor<MealPlanEntry>(
            predicate: #Predicate { $0.date >= lower && $0.date < upper },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func planMeal(recipeID: String, on date: Date, meal: MealType) throws -> MealPlanEntry {
        guard recipe(id: recipeID) != nil else { throw LarderError.recipeNotFound }
        let day = Calendar.current.startOfDay(for: date)
        let id = Self.entryID(date: day, meal: meal)
        if let existing = plannedMeal(id: id) {
            existing.recipeID = recipeID
            try context.save()
            return existing
        }
        let entry = MealPlanEntry(id: id, date: day, meal: meal, recipeID: recipeID)
        context.insert(entry)
        try context.save()
        return entry
    }

    func removePlannedMeal(id: String) throws {
        guard let entry = plannedMeal(id: id) else { throw LarderError.plannedMealNotFound }
        context.delete(entry)
        try context.save()
    }

    // MARK: Shopping

    func allShoppingLists() -> [ShoppingList] {
        (try? context.fetch(FetchDescriptor<ShoppingList>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    func shoppingList(id: String) -> ShoppingList? {
        var descriptor = FetchDescriptor<ShoppingList>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func items(inList listID: String) -> [ShoppingItem] {
        let descriptor = FetchDescriptor<ShoppingItem>(
            predicate: #Predicate { $0.listID == listID },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Adds only what isn't already on the list unchecked, and returns the names it added.
    @discardableResult
    func addItems(_ names: [String], toList listID: String) throws -> [String] {
        guard shoppingList(id: listID) != nil else { throw LarderError.shoppingListNotFound }
        let existing = Set(items(inList: listID).filter { !$0.isChecked }.map { $0.name.lowercased() })
        let added = names.filter { !existing.contains($0.lowercased()) }
        for (offset, name) in added.enumerated() {
            let createdAt = Date.now.addingTimeInterval(Double(offset) / 1000)
            context.insert(ShoppingItem(listID: listID, name: name, createdAt: createdAt))
        }
        try context.save()
        return added
    }

    func clearList(id listID: String) throws {
        guard shoppingList(id: listID) != nil else { throw LarderError.shoppingListNotFound }
        items(inList: listID).forEach(context.delete)
        try context.save()
    }

    // MARK: Journal

    func journalEntry(id: String) -> JournalEntry? {
        var descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func allJournalEntries() -> [JournalEntry] {
        (try? context.fetch(FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
    }

    func addJournalEntry(title: String?, message: String, date: Date) throws -> JournalEntry {
        let entry = JournalEntry(title: title, message: message, date: date)
        context.insert(entry)
        try context.save()
        return entry
    }

    // MARK: Navigation

    func open(recipeID: String) {
        selectedTab = .home
        homePath = NavigationPath([RecipeRoute(id: recipeID)])
    }

    func startCooking(recipeID: String) {
        if cooking?.recipeID != recipeID {
            cooking = CookingSession(recipeID: recipeID)
        }
        isCookingPresented = true
    }

    /// Takes the step by value: writing through `cooking?.step` while computing the new value from
    /// `cooking` is an overlapping access, which traps at runtime.
    func goToStep(_ step: Int) {
        cooking?.step = step
    }

    func stopCooking() {
        cooking = nil
        isCookingPresented = false
    }

    // MARK: Spotlight

    /// Siri finds recipes in Spotlight without launching the app, so the index has to stay current.
    func reindexRecipes() async throws {
        try await CSSearchableIndex.default().indexAppEntities(allRecipes().map(RecipeEntity.init))
    }

    func reindex(recipeID: String) async throws {
        guard let recipe = recipe(id: recipeID) else { return }
        try await CSSearchableIndex.default().indexAppEntities([RecipeEntity(recipe)])
    }

    // MARK: Demo data

    private func seedIfNeeded() {
        let count = (try? context.fetchCount(FetchDescriptor<Recipe>())) ?? 0
        guard count == 0 else { return }
        insertSeed()
    }

    private func insertSeed() {
        SeedData.recipes().forEach(context.insert)
        SeedData.shoppingLists().forEach(context.insert)
        try? context.save()
    }

    func resetDemoData() async throws {
        try context.delete(model: Recipe.self)
        try context.delete(model: MealPlanEntry.self)
        try context.delete(model: ShoppingList.self)
        try context.delete(model: ShoppingItem.self)
        try context.delete(model: JournalEntry.self)
        try context.save()
        insertSeed()
        homePath = NavigationPath()
        stopCooking()
        try await CSSearchableIndex.default().deleteAppEntities(ofType: RecipeEntity.self)
        try await reindexRecipes()
    }
}

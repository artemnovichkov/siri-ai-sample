import AppIntentsTesting
import XCTest

/// Runs intents out of process against the installed app, the same way Siri and Shortcuts do. This
/// checks that the tools work. Whether Siri picks them is what LarderSiriEvaluations checks.
final class LarderIntentTests: XCTestCase {
    private let definitions = IntentDefinitions(bundleIdentifier: "com.artemnovichkov.Larder")

    private var recipes: AppEntityDefinition { definitions.entities["RecipeEntity"] }
    private var lists: AppEntityDefinition { definitions.entities["ShoppingListEntity"] }

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        // The system registers an app's intents once it has launched after install.
        await Self.launchApp()
        try await resetDemoData()
    }

    /// Registration finishes shortly after the first launch, so a fresh install can report that the
    /// app "is not present" for a few seconds.
    private func resetDemoData() async throws {
        let deadline = ContinuousClock.now + .seconds(60)
        while true {
            do {
                try await definitions.intents["ResetDemoDataIntent"].makeIntent().run()
                return
            } catch {
                guard ContinuousClock.now < deadline else { throw error }
                try await Task.sleep(for: .seconds(2))
            }
        }
    }

    @MainActor
    private static func launchApp() {
        XCUIApplication().launch()
    }

    func testSeedRecipesAreFoundByName() async throws {
        let matches = try await recipes.entities(matching: "Shakshuka")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(try matches[0].name, "Shakshuka")
        XCTAssertEqual(matches[0].identifier.instanceIdentifier, "shakshuka")
    }

    func testPlanMealReturnsThePlannedMeal() async throws {
        let result = try await definitions.intents["PlanMealIntent"].makeIntent(
            recipe: recipes.makeReference(identifier: "shakshuka"),
            date: Date(),
            meal: "dinner"
        ).run()
        XCTAssertEqual(try result.value.recipe.name, "Shakshuka")
    }

    func testGetMealPlanSeesWhatPlanMealPlanned() async throws {
        let before = try await definitions.intents["GetMealPlanIntent"].makeIntent(days: 1).run()
        let emptyPlan: [AnyAppEntity] = try before.value
        XCTAssertTrue(emptyPlan.isEmpty)

        try await definitions.intents["PlanMealIntent"].makeIntent(
            recipe: recipes.makeReference(identifier: "pad-thai"),
            date: Date(),
            meal: "lunch"
        ).run()

        let after = try await definitions.intents["GetMealPlanIntent"].makeIntent(days: 1).run()
        let plan: [AnyAppEntity] = try after.value
        XCTAssertEqual(plan.count, 1)
    }

    func testAddIngredientsSkipsWhatIsAlreadyOnTheList() async throws {
        let add = definitions.intents["AddRecipeIngredientsIntent"]
        let reference = recipes.makeReference(identifier: "overnight-oats")

        let first = try await add.makeIntent(recipe: reference).run()
        let afterFirst: [String] = try first.value.remainingItems
        XCTAssertEqual(afterFirst.count, 5)

        let second = try await add.makeIntent(recipe: reference).run()
        let afterSecond: [String] = try second.value.remainingItems
        XCTAssertEqual(afterSecond.count, 5)
    }

    func testAddItemUsesTheNamedList() async throws {
        let result = try await definitions.intents["AddItemToShoppingListIntent"].makeIntent(
            item: "basil",
            list: lists.makeReference(identifier: "farmers-market")
        ).run()
        XCTAssertEqual(try result.value.name, "Farmers Market")
        let items: [String] = try result.value.remainingItems
        XCTAssertEqual(items, ["basil"])
    }

    func testShoppingListsAreEnumerable() async throws {
        let all = try await lists.allEntities()
        XCTAssertEqual(all.map(\.identifier.instanceIdentifier).sorted(), ["farmers-market", "groceries"])
    }

    func testReplacingAPlannedMealKeepsOneMealInTheSlot() async throws {
        let plan = definitions.intents["PlanMealIntent"]
        let today = Date()
        try await plan.makeIntent(recipe: recipes.makeReference(identifier: "pad-thai"), date: today, meal: "dinner").run()
        // AppIntentsTesting answers requestConfirmation itself, so this covers the confirmed path.
        let replaced = try await plan.makeIntent(recipe: recipes.makeReference(identifier: "shakshuka"), date: today, meal: "dinner").run()
        XCTAssertEqual(try replaced.value.recipe.name, "Shakshuka")

        let result = try await definitions.intents["GetMealPlanIntent"].makeIntent(days: 1).run()
        let meals: [AnyAppEntity] = try result.value
        XCTAssertEqual(meals.count, 1)
    }

    func testRemovePlannedMealTakesItOffThePlan() async throws {
        let planned = try await definitions.intents["PlanMealIntent"].makeIntent(
            recipe: recipes.makeReference(identifier: "lentil-soup"),
            date: Date(),
            meal: "lunch"
        ).run()
        try await definitions.intents["RemovePlannedMealIntent"].makeIntent(plannedMeal: planned.value).run()

        let result = try await definitions.intents["GetMealPlanIntent"].makeIntent(days: 1).run()
        let meals: [AnyAppEntity] = try result.value
        XCTAssertTrue(meals.isEmpty)
    }

    func testClearShoppingListEmptiesIt() async throws {
        let groceries = lists.makeReference(identifier: "groceries")
        try await definitions.intents["AddItemToShoppingListIntent"].makeIntent(item: "milk", list: groceries).run()
        try await definitions.intents["ClearShoppingListIntent"].makeIntent(list: groceries).run()

        let result = try await definitions.intents["GetShoppingListIntent"].makeIntent().run()
        XCTAssertEqual(try result.value.name, "Groceries")
        let items: [String] = try result.value.remainingItems
        XCTAssertTrue(items.isEmpty)
    }

    func testShowRecipeCardReturnsTheRecipe() async throws {
        let result = try await definitions.intents["ShowRecipeCardIntent"].makeIntent(
            recipe: recipes.makeReference(identifier: "margherita-pizza")
        ).run()
        XCTAssertEqual(try result.value.name, "Margherita Pizza")
    }

    func testLogCookedMealSavesAJournalEntry() async throws {
        try await definitions.intents["LogCookedMealIntent"].makeIntent(
            title: "Pad Thai",
            message: "Came out great"
        ).run()
        let entries = try await definitions.entities["JournalEntryEntity"].allEntities()
        XCTAssertEqual(entries.count, 1)
    }

    private func makeDraft(name: String, ingredients: [AnyTransientAppEntity]) -> AnyTransientAppEntity {
        definitions.transientEntities["RecipeDraft"].makeEntity(
            name: name,
            summary: "Fluffy eggs with cheese.",
            cuisine: "other",
            minutes: 10,
            servings: 2,
            ingredients: ingredients,
            instructions: "Whisk the eggs. Cook gently. Fold in the cheese."
        )
    }

    func testCreateRecipeSavesWhatTheModelWrote() async throws {
        let eggs = definitions.transientEntities["IngredientDraft"].makeEntity(name: "eggs", amount: 3.0)
        let cheese = definitions.transientEntities["IngredientDraft"].makeEntity(name: "cheese", amount: 50.0, unit: "g")

        let result = try await definitions.intents["CreateRecipeIntent"].makeIntent(
            draft: makeDraft(name: "Sunday Omelette", ingredients: [eggs, cheese])
        ).run()

        XCTAssertEqual(try result.value.name, "Sunday Omelette")
        let ingredients: [String] = try result.value.ingredients
        XCTAssertEqual(ingredients, ["3 eggs", "50 g cheese"])

        let found = try await recipes.entities(matching: "Sunday Omelette")
        XCTAssertEqual(found.count, 1)
    }

    func testCreateRecipeRejectsADraftWithNoIngredients() async throws {
        do {
            _ = try await definitions.intents["CreateRecipeIntent"].makeIntent(
                draft: makeDraft(name: "Air", ingredients: [])
            ).run()
            XCTFail("A draft with no ingredients should throw")
        } catch {
            // Expected: nothing checks a generable value before perform() does.
        }
        let found = try await recipes.entities(matching: "Air")
        XCTAssertTrue(found.isEmpty)
    }

    func testOpenRecipeAnnotatesItOnScreen() async throws {
        try await definitions.intents["OpenRecipeIntent"].makeIntent(
            target: recipes.makeReference(identifier: "shakshuka")
        ).run()
        try await Task.sleep(for: .seconds(2))

        let annotations = try await recipes.viewAnnotations()
        let ids = annotations.map(\.entity.identifier.instanceIdentifier)
        XCTAssertTrue(ids.contains("shakshuka"), "On screen: \(ids)")
    }

    /// Home opens with several recipes on screen, so "the second one" needs an annotation on each card.
    func testHomeAnnotatesEachRecipeOnScreen() async throws {
        try await Task.sleep(for: .seconds(2))
        let annotations = try await recipes.viewAnnotations()
        let ids = Set(annotations.map(\.entity.identifier.instanceIdentifier))
        XCTAssertGreaterThan(ids.count, 1, "On screen: \(ids)")
    }

    func testRecipesAreIndexedInSpotlight() async throws {
        try await Task.sleep(for: .seconds(2))
        let hits = try await recipes.spotlightQuery("Shakshuka")
        XCTAssertFalse(hits.isEmpty)
    }
}

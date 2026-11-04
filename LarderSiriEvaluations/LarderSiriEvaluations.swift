import SiriEvaluations
import Testing

// Drives real Siri, so it needs a physical device on iOS 27.3 with Apple Intelligence on and its
// models downloaded. Launch the app once after installing so its intents register and its recipes
// reach Spotlight. Keep the device unlocked and untouched. Each turn can take up to a minute, and
// Siri's answers vary between runs, so run the suite more than once.

struct LarderEvaluation: Evaluation {
    let name: String
    let dataset: SiriScenarioLoader

    func subject(from sample: SiriScenario) async throws -> SiriScenarioSubject {
        try await resetDemoData()
        let subject = try await SiriService.run(scenario: sample)
        do { try await resetDemoData() } catch { Issue.record(error) }
        return subject
    }

    var evaluators: Evaluators {
        SiriExpectationEvaluator()
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        Self.computeSiriMetrics(into: &aggregator)
    }

    private func resetDemoData() async throws {
        try await IntentDefinitions(bundleIdentifier: "com.artemnovichkov.Larder")
            .intents["ResetDemoDataIntent"]
            .makeIntent()
            .run()
    }
}

@Suite("Larder - Siri", .serialized)
struct LarderSiriEvaluationTests {
    static let app = IntentDefinitions(bundleIdentifier: "com.artemnovichkov.Larder")

    static let PlanMeal = app.intents["PlanMealIntent"]
    static let GetMealPlan = app.intents["GetMealPlanIntent"]
    static let RemovePlannedMeal = app.intents["RemovePlannedMealIntent"]
    static let AddRecipeIngredients = app.intents["AddRecipeIngredientsIntent"]
    static let AddItem = app.intents["AddItemToShoppingListIntent"]
    static let GetShoppingList = app.intents["GetShoppingListIntent"]
    static let ClearShoppingList = app.intents["ClearShoppingListIntent"]
    static let CreateRecipe = app.intents["CreateRecipeIntent"]
    static let ShowRecipeCard = app.intents["ShowRecipeCardIntent"]
    static let LogCookedMeal = app.intents["LogCookedMealIntent"]

    static let Recipe = app.entities["RecipeEntity"]
    static let ShoppingList = app.entities["ShoppingListEntity"]

    static let MealPlanningSkill = app.skills["meal-planning"]
    static let ShoppingListSkill = app.skills["shopping-list"]

    // MARK: Tools and entity parameters

    static let planWithAppName = SiriScenario {
        UserTurn("In Larder, plan shakshuka for dinner on Friday") {
            Calls {
                PlanMeal.expect(recipe: Recipe.expectIdentifier("shakshuka"))
            }
            Calls(.disallowed) { RemovePlannedMeal; ClearShoppingList }
        }
    }

    static let planParaphrase = SiriScenario {
        UserTurn("Put the pad thai on the Larder menu for tomorrow's lunch") {
            Calls {
                PlanMeal.expect(recipe: Recipe.expectIdentifier("pad-thai"))
            }
        }
    }

    static let planEvaluation = LarderEvaluation(
        name: "Larder - Plan a meal",
        dataset: SiriScenarioLoader { planWithAppName; planParaphrase }
    )

    @Test("Siri plans the right recipe", .evaluates(planEvaluation))
    func plansMeal() {
        let result = EvaluationContext.current.result
        #expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
    }

    // MARK: Telling similar tools apart

    static let singleItem = SiriScenario {
        UserTurn("Add milk to my groceries in Larder") {
            Calls {
                AddItem.expect(item: .contains("milk"))
            }
            Calls(.disallowed) { AddRecipeIngredients }
        }
    }

    static let wholeRecipe = SiriScenario {
        UserTurn("In Larder, add what I need for the fish tacos to my shopping list") {
            Calls {
                AddRecipeIngredients.expect(recipe: Recipe.expectIdentifier("fish-tacos"))
            }
            Calls(.disallowed) { ClearShoppingList }
        }
    }

    static let namedList = SiriScenario {
        UserTurn("Add basil to my Farmers Market list in Larder") {
            Calls {
                AddItem.expect(list: ShoppingList.expectIdentifier("farmers-market"))
            }
        }
    }

    static let shoppingEvaluation = LarderEvaluation(
        name: "Larder - Shopping tools",
        dataset: SiriScenarioLoader { singleItem; wholeRecipe; namedList }
    )

    @Test("Siri tells recipe ingredients from single items", .evaluates(shoppingEvaluation))
    func choosesShoppingTool() {
        let result = EvaluationContext.current.result
        #expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
    }

    // MARK: Generable entity

    static let createRecipe = SiriScenario {
        UserTurn("In Larder, save a recipe for Sunday Omelette. It takes 10 minutes, serves 2, and uses 3 eggs and 50 grams of cheese.") {
            Calls { CreateRecipe }
        }
    }

    static let createRecipeEvaluation = LarderEvaluation(
        name: "Larder - Create a recipe",
        dataset: SiriScenarioLoader { createRecipe }
    )

    @Test("Siri writes a recipe draft from the request", .evaluates(createRecipeEvaluation))
    func createsRecipe() {
        let result = EvaluationContext.current.result
        #expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
    }

    // MARK: Spotlight

    static let findRecipe = SiriScenario {
        UserTurn("Do I have a recipe with lentils in Larder?") {
            Finds { Recipe.expect(name: .contains("Lentil")) }
        }
    }

    static let findEvaluation = LarderEvaluation(
        name: "Larder - Find recipes",
        dataset: SiriScenarioLoader { findRecipe }
    )

    @Test("Siri finds recipes in Spotlight", .evaluates(findEvaluation))
    func findsRecipe() {
        let result = EvaluationContext.current.result
        #expect(result.aggregateValue(.mean(of: .foundEntitiesAllPass)) == 1.0)
    }

    // MARK: Destructive tools

    static let noAccidentalClear = SiriScenario {
        UserTurn("I'm done shopping in Larder") {
            Calls(.disallowed) { ClearShoppingList }
        }
    }

    static let destructiveEvaluation = LarderEvaluation(
        name: "Larder - Destructive tools",
        dataset: SiriScenarioLoader { noAccidentalClear }
    )

    @Test("Siri doesn't clear a list unless asked", .evaluates(destructiveEvaluation))
    func doesNotClearList() {
        let result = EvaluationContext.current.result
        #expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
    }

    // MARK: App skills. Every skill the app ships gets a scenario.

    static let planWeek = SiriScenario {
        UserTurn("In Larder, plan my dinners for the week") {
            Loads(.required) { MealPlanningSkill }
        }
    }

    static let shopForPlan = SiriScenario {
        UserTurn("In Larder, get me ready to shop for what's planned this week") {
            Loads(.required) { ShoppingListSkill }
            Calls(.disallowed) { ClearShoppingList }
        }
    }

    static let skillsEvaluation = LarderEvaluation(
        name: "Larder - App skills",
        dataset: SiriScenarioLoader { planWeek; shopForPlan }
    )

    @Test("Siri loads Larder's app skills", .evaluates(skillsEvaluation))
    func loadsSkills() {
        let result = EvaluationContext.current.result
        #expect(result.aggregateValue(.mean(of: .skillsLoadedAllPass)) == 1.0)
    }
}

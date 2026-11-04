import Foundation
import FoundationModels
import Observation
import os

/// Guided generation over the app's data. A schema guarantees the shape of a value, not that it's
/// true, so the app checks every name and schedules the result itself.
@MainActor
@Observable
final class WeekPlanner {
    struct Dinner: Identifiable {
        let date: Date
        let recipe: Recipe
        let reason: String

        var id: Date { date }
    }

    private(set) var dinners: [Dinner] = []
    private(set) var isGenerating = false
    var errorMessage: String?

    func suggest(preferences: String, store: LarderStore) async {
        isGenerating = true
        errorMessage = nil
        dinners = []
        defer { isGenerating = false }

        let freeDays = Self.nextSevenDays().filter { store.plannedMeal(on: $0, meal: .dinner) == nil }
        guard !freeDays.isEmpty else {
            errorMessage = "Every dinner is already planned for the next seven days."
            return
        }

        let recipes = store.allRecipes()
        let session = LanguageModelSession(instructions: ChefPrompts.weekInstructions)
        do {
            let response = try await session.respond(
                to: ChefPrompts.week(
                    recipes: recipes.map { "\($0.name): \($0.summary)" },
                    preferences: preferences
                ),
                generating: DinnerPicks.self
            )
            Logger(subsystem: "com.artemnovichkov.Larder", category: "Chef")
                .notice("Week picks: \(response.content.dinners.map(\.recipeName), privacy: .public)")
            // The prompt lists recipes as "Name: summary", so accept a pick that echoes the whole line.
            let recipe = { (pick: DinnerPick) in
                let name = pick.recipeName.split(separator: ":").first.map(String.init) ?? pick.recipeName
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                return recipes.first { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
            }
            dinners = WeekSchedule.assign(
                picks: response.content.dinners,
                to: freeDays,
                key: \.recipeName,
                duration: { recipe($0)?.minutes }
            )
            .compactMap { assignment in
                recipe(assignment.dish).map { Dinner(date: assignment.day, recipe: $0, reason: assignment.dish.reason) }
            }
            if dinners.isEmpty {
                errorMessage = "Chef couldn't match any suggestions to your recipes. Try again."
            }
        } catch {
            errorMessage = ChefModel.message(for: error)
        }
    }

    func apply(store: LarderStore) throws {
        for dinner in dinners {
            try store.planMeal(recipeID: dinner.recipe.id, on: dinner.date, meal: .dinner)
        }
    }

    private static func nextSevenDays() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0...6).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
}

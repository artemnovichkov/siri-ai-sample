import AppIntents

/// App Shortcuts are separate from tools. They need exact phrases, and they work without Siri AI, in
/// Spotlight and the Shortcuts app, which also makes them a quick way to try intents in the Simulator.
struct LarderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetMealPlanIntent(),
            phrases: ["What's on the meal plan in \(.applicationName)", "Show my \(.applicationName) meal plan"],
            shortTitle: "Meal Plan",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: GetShoppingListIntent(),
            phrases: ["What's on my shopping list in \(.applicationName)", "Show my \(.applicationName) shopping list"],
            shortTitle: "Shopping List",
            systemImageName: "cart"
        )
    }
}

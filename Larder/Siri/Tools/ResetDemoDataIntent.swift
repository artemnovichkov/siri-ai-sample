import AppIntents

#if DEBUG
/// Test fixture. AppIntentsTesting and SiriEvaluations run out of process and can't inject anything,
/// so tests arrange known data by running this intent in the app.
struct ResetDemoDataIntent: AppIntent {
    static let title: LocalizedStringResource = "Reset Demo Data"
    static let description = IntentDescription("Restores Larder's sample recipes and empties the plan, lists, and journal.")
    static let isDiscoverable = false

    @Dependency private var store: LarderStore

    @MainActor
    func perform() async throws -> some IntentResult {
        try await store.resetDemoData()
        return .result()
    }
}
#endif

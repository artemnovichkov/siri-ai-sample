import FoundationModels

/// Records what the model wants to add instead of adding it. In testing, the model called a direct
/// "add to groceries" tool when someone only asked about a substitution, so a person has to confirm.
/// Tools are for what the model decides to do mid-conversation. Data every request needs, like the
/// recipe list for planning, goes in the prompt: given a listing tool, the model called it in a loop
/// until it ran out of context.
struct ProposeGroceriesTool: Tool {
    let name = "proposeGroceries"
    let description = "Offers the person a button that adds items to their Groceries list. Use only when they explicitly ask to buy or add something."

    // Weak, because the chat owns the session and the session owns this tool.
    weak let chat: RecipeChat?

    @Generable
    struct Arguments {
        @Guide(description: "One item to buy, such as sweet paprika", .count(1...10))
        var items: [String]
    }

    func call(arguments: Arguments) async throws -> String {
        await chat?.propose(arguments.items)
        return "The person now sees a button to add these items. They aren't on the list until the person taps it, so don't say they were added."
    }
}

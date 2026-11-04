import SwiftUI

/// A map from each AI feature to where it lives in the code and how to try it.
struct SiriExamplesView: View {
    @Environment(LarderStore.self) private var store
    @State private var status: String?
    @State private var modelStatus = "Checking…"

    var body: some View {
        List {
            Section {
                ForEach(SiriFeature.all, content: row)
            } header: {
                Text("Siri AI")
            } footer: {
                Text("Siri AI needs a physical device with Apple Intelligence on iOS 27.3. It doesn't run in the Simulator.")
            }
            Section {
                ForEach(SiriFeature.foundationModels, content: row)
            } header: {
                Text("Foundation Models")
            } footer: {
                Text("On-device model: \(modelStatus)")
            }
            Section {
                Button("Reindex Recipes in Spotlight", systemImage: "magnifyingglass") {
                    run("Recipes indexed.") { try await store.reindexRecipes() }
                }
                Button("Reset Demo Data", systemImage: "arrow.counterclockwise", role: .destructive) {
                    run("Demo data restored.") { try await store.resetDemoData() }
                }
            } footer: {
                if let status { Text(status) }
            }
        }
        .navigationTitle("AI Examples")
        .navigationBarTitleDisplayMode(.large)
        // Reading the variant can block for seconds in the Simulator, which would stall the push.
        .task { modelStatus = await Task.detached { ChefModel.statusDescription }.value }
        .navigationDestination(for: SiriFeature.ID.self) { id in
            if let feature = (SiriFeature.all + SiriFeature.foundationModels).first(where: { $0.id == id }) {
                SiriFeatureDetailView(feature: feature)
            }
        }
    }

    private func row(_ feature: SiriFeature) -> some View {
        NavigationLink(value: feature.id) {
            HStack(spacing: 12) {
                Image(systemName: feature.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.tint, in: .rect(cornerRadius: 7))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.title)
                    Text(feature.api)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func run(_ success: String, _ action: @escaping @MainActor () async throws -> Void) {
        Task {
            do {
                try await action()
                status = success
            } catch {
                status = error.localizedDescription
            }
        }
    }
}

private struct SiriFeatureDetailView: View {
    let feature: SiriFeature

    var body: some View {
        List {
            Section { Text(feature.summary) }
            Section("API") { Text(feature.api).font(.callout.monospaced()) }
            Section("Code") { Text(feature.file).font(.callout.monospaced()) }
            if !feature.phrases.isEmpty {
                Section("Try") {
                    ForEach(feature.phrases, id: \.self) { phrase in
                        Text("“\(phrase)”").textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle(feature.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SiriFeature: Identifiable {
    let title: String
    let api: String
    let file: String
    let summary: String
    let phrases: [String]

    var id: String { title }

    var symbol: String {
        switch title {
        case "Invent a Recipe": "wand.and.stars"
        case "Read a Photo": "camera.viewfinder"
        case "Suggest a Week": "calendar"
        case "Ask Chef": "bubble.left.and.text.bubble.right.fill"
        case "Tool Intents": "hammer.fill"
        case "Finding Entities in Spotlight": "magnifyingglass"
        case "Finding Entities by Query": "list.bullet"
        case "Protecting Entity Properties": "lock.fill"
        case "Letting Siri Write Values": "square.and.pencil"
        case "Schema as a Tool": "book.closed.fill"
        case "App Skills": "graduationcap.fill"
        case "Onscreen Context": "iphone"
        case "Donations": "hand.tap.fill"
        case "Transferable Entities": "square.and.arrow.up"
        case "Card Snippets": "rectangle.on.rectangle"
        case "Verifying the Integration": "checkmark.seal.fill"
        default: "sparkles"
        }
    }

    static let foundationModels: [SiriFeature] = [
        SiriFeature(
            title: "Invent a Recipe",
            api: "@Generable, streamResponse(generating:)",
            file: "AI/RecipeInventor.swift",
            summary: "Guided generation returns a typed recipe, and streaming shows each property as it arrives. Saving it indexes the recipe, so Siri can find it too.",
            phrases: ["Home > ✨ > “Eggs, spinach, feta”"]
        ),
        SiriFeature(
            title: "Read a Photo",
            api: "Attachment, respond(generating:)",
            file: "AI/RecipeInventor.swift",
            summary: "A multimodal prompt lists the food in a photo and fills in the ingredients.",
            phrases: ["Home > ✨ > Camera button"]
        ),
        SiriFeature(
            title: "Suggest a Week",
            api: "@Generable, respond(to:generating:)",
            file: "AI/WeekPlanner.swift",
            summary: "The model only chooses dishes from your recipes. Code checks the names, removes repeats, and schedules them on free days, because the model doesn't follow those rules reliably.",
            phrases: ["Plan > ✨ > “Quick on weeknights, no fish”"]
        ),
        SiriFeature(
            title: "Ask Chef",
            api: "LanguageModelSession, Tool, streamResponse(to:)",
            file: "AI/RecipeChat.swift",
            summary: "A multi-turn conversation about one recipe that takes its family notes into account. A tool lets the model offer a button for adding groceries, and nothing changes until you tap it.",
            phrases: ["Open a recipe > ✨ > “What can I substitute?”"]
        ),
    ]

    static let all: [SiriFeature] = [
        SiriFeature(
            title: "Tool Intents",
            api: "@AppIntent(.tool)",
            file: "Siri/Tools/MealPlanTools.swift",
            summary: "Turns an intent into a tool Siri can choose and fill. Siri relies on the titles and descriptions of the intent and its parameters. Tools have to work whenever they're called, so destructive ones keep a confirmation.",
            phrases: [
                "In Larder, plan shakshuka for dinner on Friday",
                "What's planned for dinner tonight in Larder?",
                "In Larder, take Friday's dinner off the plan",
            ]
        ),
        SiriFeature(
            title: "Finding Entities in Spotlight",
            api: "IndexedEntity, IndexedEntityQuery",
            file: "Siri/Entities/RecipeEntity.swift",
            summary: "Siri looks up recipes in Spotlight without launching the app, even when the request doesn't name it. That's why the app has no search tool: tools take the entity as a parameter.",
            phrases: ["Do I have a recipe with lentils?", "How long does the pad thai take?"]
        ),
        SiriFeature(
            title: "Finding Entities by Query",
            api: "EnumerableEntityQuery",
            file: "Siri/Entities/ShoppingListEntity.swift",
            summary: "Fits a small, bounded set that isn't worth indexing. It runs the app's code, and Siri only uses it when the request names the app.",
            phrases: ["In Larder, what's on my Farmers Market list?", "Add basil to my Farmers Market list in Larder"]
        ),
        SiriFeature(
            title: "Protecting Entity Properties",
            api: "@Property(authenticationPolicy:), @Property(visibility: .internal)",
            file: "Siri/Entities/RecipeEntity.swift",
            summary: "Family Notes ask to unlock the device before Siri reads them. Revision stays inside the app and its extensions, so Siri, Shortcuts, and Spotlight never see it.",
            phrases: ["In Larder, what are the family notes on the shakshuka?"]
        ),
        SiriFeature(
            title: "Letting Siri Write Values",
            api: "@AppEntity(.generable)",
            file: "Siri/Entities/RecipeDraft.swift",
            summary: "A generable entity is a plain value the model writes from the conversation, with no query involved. perform() validates it because nothing else has.",
            phrases: ["In Larder, save a recipe for Sunday Omelette. It takes 10 minutes, serves 2, and uses 3 eggs and 50 grams of cheese."]
        ),
        SiriFeature(
            title: "Schema as a Tool",
            api: "@AppIntent(.tool, schema: .journal.createEntry)",
            file: "Siri/Tools/RecipeTools.swift",
            summary: "Only Shortcuts-only schema domains combine with .tool. Primary domains like messages or notes are already handled by Siri, and combining them with .tool is a build error.",
            phrases: ["In Larder, log that the pad thai came out great"]
        ),
        SiriFeature(
            title: "App Skills",
            api: "Skills.skillsbundle/Skills/<name>/SKILL.md",
            file: "Skills.skillsbundle",
            summary: "Task context and orchestration across tools. Siri matches on the description and reads the body only after a match. Skills guide Siri but don't make its behavior deterministic.",
            phrases: ["In Larder, plan my dinners for the week", "In Larder, get me ready to shop for what's planned"]
        ),
        SiriFeature(
            title: "Onscreen Context",
            api: ".userActivity, .appEntityIdentifier(_:), .appEntityIdentifier(forSelectionType:)",
            file: "Views/RecipeDetailView.swift, Components/RecipeShelves.swift",
            summary: "Connects what's on screen to entities, so “this recipe” or “the second one” resolves. Open a recipe first.",
            phrases: ["Add this to my shopping list", "Plan this for lunch tomorrow"]
        ),
        SiriFeature(
            title: "Donations",
            api: "IntentDonationManager.shared.donate(intent:)",
            file: "Views/RecipeDetailView.swift",
            summary: "The system only donates intents it runs. A tap in the app's own UI has to donate the matching intent, which gives Siri a behavioral cue for ambiguous requests.",
            phrases: []
        ),
        SiriFeature(
            title: "Transferable Entities",
            api: "RecipeEntity: Transferable",
            file: "Siri/Entities/RecipeEntity.swift",
            summary: "Lets Siri pass a recipe to another app in a single request. The exported text leaves out the family notes.",
            phrases: ["Email the shakshuka recipe from Larder to Sam"]
        ),
        SiriFeature(
            title: "Card Snippets",
            api: "SnippetIntent, ShowsSnippetIntent",
            file: "Siri/Tools/RecipeCardSnippet.swift",
            summary: "Shows your own view in Siri's response. The button runs an intent, and the system then re-runs the snippet to redraw it.",
            phrases: ["In Larder, show me the margherita pizza"]
        ),
        SiriFeature(
            title: "Verifying the Integration",
            api: "sirimetadataanalyzer, AppIntentsTesting, SiriEvaluations",
            file: "LarderIntentTests, LarderSiriEvaluations",
            summary: "The analyzer checks built metadata. AppIntentsTesting runs intents out of process, in the Simulator too. SiriEvaluations scripts conversations with real Siri on a device.",
            phrases: []
        ),
    ]
}

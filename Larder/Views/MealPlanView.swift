import SwiftData
import SwiftUI

struct MealPlanView: View {
    @Environment(LarderStore.self) private var store
    @Query(sort: \MealPlanEntry.date) private var entries: [MealPlanEntry]
    @Query private var recipes: [Recipe]
    @State private var isSuggesting = false

    private var days: [(day: Date, entries: [MealPlanEntry])] {
        Dictionary(grouping: entries, by: \.date)
            .sorted { $0.key < $1.key }
            .map { (day: $0.key, entries: $0.value.sorted { $0.meal.order < $1.meal.order }) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            row(entry)
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 66 }
                                .swipeActions {
                                    Button("Remove", systemImage: "trash", role: .destructive) {
                                        try? store.removePlannedMeal(id: entry.id)
                                    }
                                }
                        }
                    } header: {
                        Text(title(for: group.day))
                            .font(.title3.bold())
                            .foregroundStyle(Color.primary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing Planned", systemImage: "calendar")
                    } description: {
                        Text("Try “In Larder, plan shakshuka for dinner on Friday.”")
                    } actions: {
                        Button("Suggest a Week", systemImage: "sparkles") { isSuggesting = true }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            .navigationTitle("Plan")
            .toolbar {
                Button("Suggest a Week", systemImage: "sparkles") { isSuggesting = true }
            }
            .sheet(isPresented: $isSuggesting) { SuggestWeekView() }
            .recipeDestinations()
        }
    }

    @ViewBuilder
    private func row(_ entry: MealPlanEntry) -> some View {
        if let recipe = recipes.first(where: { $0.id == entry.recipeID }) {
            NavigationLink(value: RecipeRoute(id: recipe.id)) {
                RecipeRow(recipe: recipe, subtitle: "\(entry.meal.title) · \(recipe.duration)")
            }
            .recipeEntity(recipe.id)
        } else {
            LabeledContent(entry.meal.title, value: "Unknown recipe")
        }
    }

    private func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

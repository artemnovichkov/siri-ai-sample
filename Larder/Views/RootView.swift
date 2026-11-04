import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(LarderStore.self) private var store
    @Query private var entries: [MealPlanEntry]
    @Query private var recipes: [Recipe]
    @Namespace private var namespace

    private var tonight: Recipe? {
        let dinner = entries.first { Calendar.current.isDateInToday($0.date) && $0.meal == .dinner }
        return recipes.first { $0.id == dinner?.recipeID }
    }

    private var cookingRecipe: Recipe? {
        recipes.first { $0.id == store.cooking?.recipeID }
    }

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) { HomeView() }
            Tab("Plan", systemImage: "calendar", value: AppTab.plan) { MealPlanView() }
            Tab("Shopping", systemImage: "cart.fill", value: AppTab.shopping) { ShoppingView() }
            Tab("Library", systemImage: "books.vertical.fill", value: AppTab.library) { LibraryView() }
            Tab(value: AppTab.search, role: .search) { SearchView() }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewSearchActivation(.searchTabSelection)
        .tabViewBottomAccessory(isEnabled: (cookingRecipe ?? tonight) != nil) {
            if let recipe = cookingRecipe ?? tonight {
                NowCookingAccessory(recipe: recipe, namespace: namespace)
            }
        }
        .sheet(isPresented: $store.isCookingPresented) {
            if let cookingRecipe {
                CookingView(recipe: cookingRecipe)
                    .navigationTransition(.zoom(sourceID: "now-cooking", in: namespace))
            }
        }
    }
}

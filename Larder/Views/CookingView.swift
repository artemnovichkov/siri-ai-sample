import SwiftUI

/// The bar above the tab bar: what's cooking now or what's planned for tonight.
struct NowCookingAccessory: View {
    @Environment(LarderStore.self) private var store
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    let recipe: Recipe
    let namespace: Namespace.ID

    private var session: LarderStore.CookingSession? {
        store.cooking?.recipeID == recipe.id ? store.cooking : nil
    }

    private var subtitle: String {
        if let session { return "Step \(session.step + 1) of \(recipe.steps.count)" }
        return "Tonight's Dinner"
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if session == nil {
                    store.open(recipeID: recipe.id)
                } else {
                    store.isCookingPresented = true
                }
            } label: {
                HStack(spacing: 10) {
                    RecipeArtwork(recipe, style: .thumbnail, cornerRadius: 7)
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(recipe.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        if placement != .inline {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if let session {
                Button("Next Step", systemImage: "forward.fill") {
                    store.goToStep(min(session.step + 1, recipe.steps.count - 1))
                }
                .labelStyle(.iconOnly)
                .disabled(session.step >= recipe.steps.count - 1)
            } else {
                Button("Start Cooking", systemImage: "play.fill") {
                    store.startCooking(recipeID: recipe.id)
                }
                .labelStyle(.iconOnly)
            }
        }
        .font(.title3)
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .matchedTransitionSource(id: "now-cooking", in: namespace)
    }
}

/// Cooking mode, modeled on Now Playing: the steps scroll like lyrics, with the current one in focus.
struct CookingView: View {
    @Environment(LarderStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var isShowingIngredients = false
    @State private var isAskingChef = false

    private var steps: [String] { recipe.steps }
    private var step: Int { store.cooking?.step ?? 0 }
    private var isLastStep: Bool { step >= steps.count - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
            progress
            transport
            bottomBar
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { ArtworkBackground(palette: ArtworkPalette(id: recipe.id, cuisine: recipe.cuisine)) }
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: step)
        // Hands are busy while cooking, so the screen shouldn't lock.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(isPresented: $isAskingChef) {
            AskChefView(recipe: RecipeEntity(recipe), store: store)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            RecipeArtwork(recipe, style: .thumbnail, cornerRadius: 10)
                .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name).font(.headline)
                Text(recipe.byline)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Button("Close", systemImage: "chevron.down") { dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var content: some View {
        if isShowingIngredients {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                        if index > 0 { Divider() }
                        Text(ingredient)
                            .font(.title3.weight(.medium))
                            .padding(.vertical, 12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                            Button {
                                store.goToStep(index)
                            } label: {
                                Text(text)
                                    .font(.title.bold())
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .opacity(index == step ? 1 : 0.32)
                                    .blur(radius: index == step ? 0 : 1.2)
                            }
                            .buttonStyle(.plain)
                            .id(index)
                            .accessibilityLabel("Step \(index + 1): \(text)")
                            .accessibilityAddTraits(index == step ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 40)
                }
                .scrollIndicators(.hidden)
                .onAppear { proxy.scrollTo(step, anchor: .center) }
                .onChange(of: step) { _, new in
                    withAnimation(.smooth) { proxy.scrollTo(new, anchor: .center) }
                }
            }
        }
    }

    private var progress: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule()
                        .fill(.white)
                        .frame(width: proxy.size.width * CGFloat(step + 1) / CGFloat(max(steps.count, 1)))
                }
            }
            .frame(height: 6)
            .animation(.smooth, value: step)
            HStack {
                Text("Step \(step + 1)")
                Spacer()
                Text(recipe.duration)
                Spacer()
                Text("\(steps.count - step - 1) left")
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.7))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of \(steps.count)")
        .padding(.vertical, 12)
    }

    private var transport: some View {
        HStack(spacing: 72) {
            Button("Previous Step", systemImage: "backward.fill") {
                store.goToStep(max(step - 1, 0))
            }
            .disabled(step == 0)

            if isLastStep {
                Button("Finish Cooking", systemImage: "checkmark") {
                    dismiss()
                    store.stopCooking()
                }
            } else {
                Button("Next Step", systemImage: "forward.fill") {
                    store.goToStep(step + 1)
                }
            }
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 40))
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var bottomBar: some View {
        HStack {
            Button("Ask Chef", systemImage: "sparkles") { isAskingChef = true }
            Spacer()
            Button("Stop Cooking", systemImage: "stop.fill") {
                dismiss()
                store.stopCooking()
            }
            Spacer()
            Button(
                isShowingIngredients ? "Show Steps" : "Show Ingredients",
                systemImage: isShowingIngredients ? "list.number" : "list.bullet"
            ) {
                withAnimation(.smooth) { isShowingIngredients.toggle() }
            }
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

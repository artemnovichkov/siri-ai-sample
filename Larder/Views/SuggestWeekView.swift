import SwiftUI

struct SuggestWeekView: View {
    @Environment(LarderStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var planner = WeekPlanner()
    @State private var preferences = ""

    private let suggestions = ["Quick on weeknights", "No fish", "Vegetarian"]

    var body: some View {
        NavigationStack {
            ModelGate {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if planner.dinners.isEmpty {
                            intro
                        } else {
                            suggestionsList
                        }
                        if planner.isGenerating {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Chef is planning…").foregroundStyle(.secondary)
                            }
                        }
                        if let error = planner.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    ChefComposer(
                        prompt: "Any preferences?",
                        text: $preferences,
                        axis: .vertical,
                        isBusy: planner.isGenerating,
                        allowsEmpty: true,
                        send: suggest
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .background { ArtworkBackground(palette: ArtworkPalette(id: "week", cuisine: .thai)) }
            .navigationTitle("Suggest a Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Plan", systemImage: "checkmark", action: apply)
                        .disabled(planner.dinners.isEmpty)
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text("Plan Your Week")
                .font(.largeTitle.bold())
            Text("Chef picks dinners from your recipes for the free days ahead.")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) { preferences = suggestion }
                        .buttonStyle(.glass)
                }
            }
            .padding(.top, 8)
        }
        .padding(.top, 24)
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Week").font(.largeTitle.bold())
            ForEach(planner.dinners) { dinner in
                HStack(alignment: .top, spacing: 12) {
                    RecipeArtwork(dinner.recipe, style: .thumbnail, cornerRadius: 8)
                        .frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dinner.date.formatted(.dateTime.weekday(.wide)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(dinner.recipe.name).font(.headline)
                        Text(dinner.reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Text("Chef only picks dishes that fit, so some days may stay free. Days with a planned dinner don't change.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func suggest() {
        guard !planner.isGenerating else { return }
        Task { await planner.suggest(preferences: preferences, store: store) }
    }

    private func apply() {
        do {
            try planner.apply(store: store)
            dismiss()
        } catch {
            planner.errorMessage = error.localizedDescription
        }
    }
}

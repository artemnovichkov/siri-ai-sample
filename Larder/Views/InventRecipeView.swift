import CoreImage
import PhotosUI
import SwiftUI

struct InventRecipeView: View {
    @Environment(LarderStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var inventor = RecipeInventor()
    @State private var ingredients = ""
    @State private var photo: PhotosPickerItem?

    private let suggestions = ["Eggs, spinach, feta", "Chickpeas, lemon, rice", "Tomatoes, basil, pasta"]

    var body: some View {
        NavigationStack {
            ModelGate {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let idea = inventor.idea {
                            RecipeIdeaContent(idea: idea)
                        } else {
                            intro
                        }
                        if let error = inventor.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) { composer }
            }
            .background { ArtworkBackground(palette: ArtworkPalette(id: "chef", cuisine: .other)) }
            .navigationTitle("Invent a Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .disabled(inventor.finishedIdea == nil)
                }
            }
            .onChange(of: photo) { _, item in
                guard let item else { return }
                Task { await read(item) }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text("What's in Your Kitchen?")
                .font(.largeTitle.bold())
            Text("Chef invents a recipe from what you have. It all happens on this device.")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) { ingredients = suggestion }
                        .buttonStyle(.glass)
                }
            }
            .padding(.top, 8)
        }
        .padding(.top, 24)
    }

    private var composer: some View {
        // PhotosPicker's label closure isn't main-actor isolated, so it gets a copy of this value.
        let isScanning = inventor.isScanning
        return ChefComposer(
            prompt: "List your ingredients",
            text: $ingredients,
            axis: .vertical,
            isBusy: inventor.isGenerating,
            send: invent
        ) {
            PhotosPicker(selection: $photo, matching: .images) {
                Group {
                    if isScanning {
                        ProgressView()
                    } else {
                        Image(systemName: "camera.viewfinder")
                    }
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(isScanning ? "Reading Photo" : "Read Ingredients from a Photo")
            .disabled(isScanning)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func invent() {
        guard !ingredients.isEmpty, !inventor.isGenerating else { return }
        Task { await inventor.invent(from: ingredients) }
    }

    private func read(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = CIImage(data: data, options: [.applyOrientationProperty: true])
        else {
            inventor.errorMessage = "Couldn't open that photo."
            return
        }
        let items = await inventor.scanIngredients(in: image)
        if !items.isEmpty {
            ingredients = items.joined(separator: ", ")
        }
    }

    private func save() {
        guard let idea = inventor.finishedIdea else { return }
        Task {
            do {
                let recipe = try await inventor.save(idea, in: store)
                store.open(recipeID: recipe.id)
                dismiss()
            } catch {
                inventor.errorMessage = error.localizedDescription
            }
        }
    }
}

/// Every property of a partially generated value is optional, so the UI fills in as the stream arrives.
private struct RecipeIdeaContent: View {
    let idea: RecipeIdea.PartiallyGenerated

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let name = idea.name {
                Text(name).font(.largeTitle.bold())
            }
            if let minutes = idea.minutes, let servings = idea.servings {
                Text("\(minutes) min · Serves \(servings)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            if let summary = idea.summary {
                Text(summary).padding(.top, 8)
            }
        }
        if let ingredients = idea.ingredients, !ingredients.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Ingredients").font(.title3.bold()).padding(.bottom, 6)
                ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                    if index > 0 { Divider() }
                    Text(ingredient).padding(.vertical, 11)
                }
            }
        }
        if let steps = idea.steps, !steps.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Method").font(.title3.bold())
                ForEach(Array(steps.enumerated()), id: \.offset) { offset, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(offset + 1)")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .leading)
                        Text(step)
                    }
                }
            }
        }
    }
}

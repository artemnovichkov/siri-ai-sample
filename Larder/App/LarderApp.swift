import AppIntents
import SwiftData
import SwiftUI

@main
struct LarderApp: App {
    private let store: LarderStore

    init() {
        let store = LarderStore.shared
        self.store = store
        // Siri can launch the process without showing any UI, so this has to happen in App.init().
        // Reading an unregistered @Dependency is an uncatchable fatalError.
        AppDependencyManager.shared.add(dependency: store)
        LarderShortcuts.updateAppShortcutParameters()
        Task { try? await store.reindexRecipes() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .modelContainer(store.container)
        }
    }
}

import AppIntents
import CoreLocation
import Foundation

/// Schema-conforming entity. The `journal` domain is Shortcuts-only, so combining it with `.tool` on
/// the intent is what brings it to Siri. See `LogCookedMealIntent`.
@AppEntity(schema: .journal.entry)
struct JournalEntryEntity {
    static let defaultQuery = JournalEntryQuery()

    let id: String

    var title: String?
    var message: AttributedString?
    var mediaItems: [IntentFile]
    var entryDate: Date?
    var location: CLPlacemark?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title ?? "Cooked meal")")
    }

    init(id: String, title: String?, message: String, date: Date) {
        self.id = id
        self.title = title
        self.message = AttributedString(message)
        self.mediaItems = []
        self.entryDate = date
        self.location = nil
    }

    @MainActor
    init(_ entry: JournalEntry) {
        self.init(id: entry.id, title: entry.title, message: entry.message, date: entry.date)
    }
}

struct JournalEntryQuery: EnumerableEntityQuery {
    @Dependency private var store: LarderStore

    @MainActor
    func allEntities() async throws -> [JournalEntryEntity] {
        store.allJournalEntries().map(JournalEntryEntity.init)
    }

    @MainActor
    func entities(for identifiers: [JournalEntryEntity.ID]) async throws -> [JournalEntryEntity] {
        identifiers.compactMap(store.journalEntry(id:)).map(JournalEntryEntity.init)
    }
}

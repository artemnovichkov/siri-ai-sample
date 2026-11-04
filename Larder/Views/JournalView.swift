import SwiftData
import SwiftUI

struct JournalView: View {
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    var body: some View {
        List(entries) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(entry.title ?? "Cooked meal").font(.headline)
                Text(entry.message)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Entries",
                    systemImage: "book.closed",
                    description: Text("Try “In Larder, log that the pad thai came out great.”")
                )
            }
        }
        .navigationTitle("Cooking Journal")
        .navigationBarTitleDisplayMode(.large)
    }
}

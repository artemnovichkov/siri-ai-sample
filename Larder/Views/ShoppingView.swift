import SwiftData
import SwiftUI

struct ShoppingView: View {
    @Query(sort: \ShoppingList.name) private var lists: [ShoppingList]
    @Query(sort: \ShoppingItem.createdAt) private var items: [ShoppingItem]

    var body: some View {
        NavigationStack {
            List(lists) { list in
                let listItems = items.filter { $0.listID == list.id }
                Section {
                    if listItems.isEmpty {
                        Text("No items").foregroundStyle(.secondary)
                    }
                    ForEach(listItems) { item in
                        @Bindable var item = item
                        Toggle(item.name, isOn: $item.isChecked)
                            .toggleStyle(CheckToggleStyle())
                            .alignmentGuide(.listRowSeparatorLeading) { dimensions in dimensions[.leading] + 38 }
                    }
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(list.name)
                            .font(.title2.bold())
                            .foregroundStyle(.tint)
                        Spacer()
                        Text(remaining(in: listItems))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .textCase(nil)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Shopping")
        }
    }

    private func remaining(in items: [ShoppingItem]) -> String {
        guard !items.isEmpty else { return "" }
        let left = items.filter { !$0.isChecked }.count
        return left == 0 ? "All done" : "\(left) left"
    }
}

/// A round checkbox, like the one in Reminders.
private struct CheckToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(configuration.isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                configuration.label
                    .foregroundStyle(configuration.isOn ? .secondary : .primary)
                    .strikethrough(configuration.isOn)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: configuration.isOn)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

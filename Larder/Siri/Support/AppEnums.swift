import AppIntents

/// An `AppEnum` gives the model a closed set of values instead of a free-form string.
enum MealType: String, AppEnum, CaseIterable {
    case breakfast, lunch, dinner

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Meal"
    static let caseDisplayRepresentations: [MealType: DisplayRepresentation] = [
        .breakfast: "Breakfast",
        .lunch: "Lunch",
        .dinner: "Dinner",
    ]

    var title: String { rawValue.capitalized }

    var order: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        }
    }
}

enum Cuisine: String, AppEnum, CaseIterable {
    case italian, mexican, thai, middleEastern, other

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Cuisine"
    static let caseDisplayRepresentations: [Cuisine: DisplayRepresentation] = [
        .italian: "Italian",
        .mexican: "Mexican",
        .thai: "Thai",
        .middleEastern: "Middle Eastern",
        .other: "Other",
    ]

    var title: String {
        switch self {
        case .italian: "Italian"
        case .mexican: "Mexican"
        case .thai: "Thai"
        case .middleEastern: "Middle Eastern"
        case .other: "Other"
        }
    }
}

enum SearchSortOption: CaseIterable {
    case releaseDate
    case title
    case voteAverage

    var label: String {
        switch self {
        case .releaseDate: return "Release Date (Newest First)"
        case .title: return "Title (A–Z)"
        case .voteAverage: return "Rating (Highest First)"
        }
    }
}

struct SearchFilterState: Equatable {
    var selectedGenreIds: Set<Int> = []
    var minimumRatingEnabled: Bool = false
    var minimumRating: Int = 5
    var fromYear: String = ""
    var toYear: String = ""

    var isDefault: Bool {
        selectedGenreIds.isEmpty &&
        !minimumRatingEnabled &&
        fromYear.isEmpty &&
        toYear.isEmpty
    }
}

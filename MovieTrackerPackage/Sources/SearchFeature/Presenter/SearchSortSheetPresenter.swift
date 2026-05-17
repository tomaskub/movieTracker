import Observation

@Observable
@MainActor
final class SearchSortSheetPresenter {
    var draftSort: SearchSortOption = .releaseDate

    private let onConfirm: (SearchSortOption) -> Void

    init(onConfirm: @escaping (SearchSortOption) -> Void) {
        self.onConfirm = onConfirm
    }

    func reset(to activeSort: SearchSortOption) {
        draftSort = activeSort
    }

    func selectSort(_ option: SearchSortOption) {
        draftSort = option
    }

    func confirm() {
        onConfirm(draftSort)
    }
}

import Foundation
import Observation
import TMDBClient

@Observable
@MainActor
final class SearchFilterSheetPresenter {
    var draftFilters: SearchFilterState = SearchFilterState()
    var genreLoadState: GenreLoadState = .loading
    var fromYearError: String? = nil
    var toYearError: String? = nil
    var yearRangeError: String? = nil

    private let interactor: any SearchFilterSheetInteractorProtocol
    private let onConfirm: (SearchFilterState) -> Void
    private let currentYear: Int

    nonisolated(unsafe) var genreTask: Task<Void, Never>?

    init(interactor: any SearchFilterSheetInteractorProtocol, onConfirm: @escaping (SearchFilterState) -> Void) {
        self.interactor = interactor
        self.onConfirm = onConfirm
        self.currentYear = Calendar.current.component(.year, from: Date())
    }

    func reset(from activeFilters: SearchFilterState) {
        draftFilters = activeFilters
        fromYearError = nil
        toYearError = nil
        yearRangeError = nil

        if case .loaded = genreLoadState {
            return
        }
        genreLoadState = .loading
        genreTask?.cancel()
        genreTask = nil
        loadGenres(force: false)
    }

    func viewAppeared() {
        if case .loaded = genreLoadState { return }
        loadGenres(force: false)
    }

    func retryGenreFetch() {
        genreTask?.cancel()
        genreTask = nil
        genreLoadState = .loading
        loadGenres(force: true)
    }

    func toggleGenre(id: Int) {
        if draftFilters.selectedGenreIds.contains(id) {
            draftFilters.selectedGenreIds.remove(id)
        } else {
            draftFilters.selectedGenreIds.insert(id)
        }
    }

    func toggleMinimumRating() {
        draftFilters.minimumRatingEnabled.toggle()
        if draftFilters.minimumRatingEnabled && draftFilters.minimumRating < 1 {
            draftFilters.minimumRating = 5
        }
    }

    func setMinimumRating(_ value: Int) {
        draftFilters.minimumRating = value.clamped(to: 1...10)
    }

    func updateFromYear(_ text: String) {
        draftFilters.fromYear = text
        validateYears()
    }

    func updateToYear(_ text: String) {
        draftFilters.toYear = text
        validateYears()
    }

    func clearAllFilters() {
        draftFilters = SearchFilterState()
        fromYearError = nil
        toYearError = nil
        yearRangeError = nil
    }

    func confirm() {
        onConfirm(draftFilters)
    }

    private func loadGenres(force: Bool) {
        genreTask = Task { [weak self] in
            guard let self else { return }
            do throws(TMDBError) {
                let genres = try await self.interactor.fetchGenres(force: force)
                guard !Task.isCancelled else { return }
                self.genreLoadState = .loaded(genres)
            } catch {
                guard !Task.isCancelled else { return }
                self.genreLoadState = .error(error)
            }
        }
    }

    private func validateYears() {
        fromYearError = nil
        toYearError = nil
        yearRangeError = nil

        let fromValid: Bool
        let toValid: Bool
        let fromInt: Int?
        let toInt: Int?

        if draftFilters.fromYear.isEmpty {
            fromValid = true
            fromInt = nil
        } else if let year = Int(draftFilters.fromYear), (1900...currentYear).contains(year) {
            fromValid = true
            fromInt = year
        } else {
            fromValid = false
            fromInt = nil
            fromYearError = "Enter a year between 1900 and \(currentYear)"
        }

        if draftFilters.toYear.isEmpty {
            toValid = true
            toInt = nil
        } else if let year = Int(draftFilters.toYear), (1900...currentYear).contains(year) {
            toValid = true
            toInt = year
        } else {
            toValid = false
            toInt = nil
            toYearError = "Enter a year between 1900 and \(currentYear)"
        }

        if fromValid, toValid, let from = fromInt, let to = toInt, from > to {
            yearRangeError = "From year must be before or equal to To year"
            fromYearError = ""
            toYearError = ""
        }
    }

    deinit {
        genreTask?.cancel()
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

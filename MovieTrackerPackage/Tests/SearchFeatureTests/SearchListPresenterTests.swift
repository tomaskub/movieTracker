import DomainModels
import Foundation
import Testing
import TMDBClient
@testable import SearchFeature

@MainActor
struct SearchListPresenterTests {

    // MARK: - Helpers

    private func makePresenter(behavior: SpySearchListInteractor.Behavior = .success(SearchFixtures.movies)) -> (SearchListPresenter, SpySearchListInteractor) {
        let interactor = SpySearchListInteractor(behavior: behavior)
        let presenter = SearchListPresenter(interactor: interactor)
        return (presenter, interactor)
    }

    // MARK: - Submit search

    @Test func submitSearch_withResults_transitionsToResults() async {
        let (presenter, _) = makePresenter()
        presenter.query = "inception"
        presenter.submitSearch()
        #expect(presenter.searchState.isLoading)
        await presenter.searchTask?.value
        #expect(presenter.searchState.isResults)
    }

    @Test func submitSearch_withEmptyArray_transitionsToNoMatches() async {
        let (presenter, _) = makePresenter(behavior: .success([]))
        presenter.query = "xyz"
        presenter.submitSearch()
        await presenter.searchTask?.value
        if case .empty(let reason) = presenter.searchState {
            #expect(reason == .noMatches)
        } else {
            Issue.record("Expected .empty(.noMatches), got \(presenter.searchState)")
        }
    }

    @Test func submitSearch_withError_transitionsToError() async {
        let (presenter, _) = makePresenter(behavior: .failure(.networkFailure))
        presenter.query = "inception"
        presenter.submitSearch()
        await presenter.searchTask?.value
        #expect(presenter.searchState.isError)
    }

    @Test func submitSearch_withWhitespaceOnly_doesNotSearch() async {
        let (presenter, interactor) = makePresenter()
        presenter.query = "   "
        presenter.submitSearch()
        #expect(interactor.searchCallCount == 0)
        #expect(presenter.searchState.isIdle)
    }

    @Test func retrySearch_reissuesSearch() async {
        let (presenter, interactor) = makePresenter(behavior: .failure(.networkFailure))
        presenter.query = "blade runner"
        presenter.submitSearch()
        await presenter.searchTask?.value
        #expect(presenter.searchState.isError)

        interactor.behavior = .success(SearchFixtures.movies)
        presenter.retrySearch()
        #expect(presenter.searchState.isLoading)
        await presenter.searchTask?.value
        #expect(presenter.searchState.isResults)
        #expect(interactor.searchCallCount == 2)
    }

    // MARK: - Filter pipeline

    @Test func commitFilters_genreFilter_narrowsResults() async {
        let (presenter, _) = makePresenter()
        presenter.query = "sci-fi"
        presenter.submitSearch()
        await presenter.searchTask?.value

        var filters = SearchFilterState()
        filters.selectedGenreIds = [28]
        presenter.commitFilters(filters)

        if case .results(_, let filtered) = presenter.searchState {
            #expect(filtered.allSatisfy { $0.genreIds.contains(28) })
        } else if case .empty(let reason) = presenter.searchState {
            #expect(reason == .filtersEliminated)
        } else {
            Issue.record("Unexpected state after filter: \(presenter.searchState)")
        }
    }

    @Test func commitFilters_allEliminated_transitionsToFiltersEliminated() async {
        let movies = [
            Movie(id: 1, title: "A", overview: "", releaseDate: "2020-01-01", genreIds: [18], posterPath: nil, voteAverage: 5.0)
        ]
        let (presenter, _) = makePresenter(behavior: .success(movies))
        presenter.query = "a"
        presenter.submitSearch()
        await presenter.searchTask?.value

        var filters = SearchFilterState()
        filters.selectedGenreIds = [999]
        presenter.commitFilters(filters)

        if case .empty(let reason) = presenter.searchState {
            #expect(reason == .filtersEliminated)
        } else {
            Issue.record("Expected .empty(.filtersEliminated)")
        }
    }

    @Test func clearActiveFilters_resetsAndRecomputes() async {
        let (presenter, _) = makePresenter()
        presenter.query = "a"
        presenter.submitSearch()
        await presenter.searchTask?.value

        var filters = SearchFilterState()
        filters.selectedGenreIds = [999]
        presenter.commitFilters(filters)
        presenter.clearActiveFilters()

        #expect(presenter.activeFilters.isDefault)
        #expect(presenter.searchState.isResults)
    }

    // MARK: - Sort

    @Test func commitSort_title_sortedAlphabetically() async {
        let movies = [
            Movie(id: 1, title: "Zebra", overview: "", releaseDate: "2020-01-01", genreIds: [], posterPath: nil, voteAverage: 5.0),
            Movie(id: 2, title: "Apple", overview: "", releaseDate: "2021-01-01", genreIds: [], posterPath: nil, voteAverage: 7.0),
            Movie(id: 3, title: "Mango", overview: "", releaseDate: "2019-01-01", genreIds: [], posterPath: nil, voteAverage: 6.0),
        ]
        let (presenter, _) = makePresenter(behavior: .success(movies))
        presenter.query = "test"
        presenter.submitSearch()
        await presenter.searchTask?.value

        presenter.commitSort(.title)
        if case .results(_, let filtered) = presenter.searchState {
            #expect(filtered.map(\.title) == ["Apple", "Mango", "Zebra"])
        } else {
            Issue.record("Expected .results")
        }
    }

    @Test func commitSort_releaseDate_sortedDescending() async {
        let movies = [
            Movie(id: 1, title: "A", overview: "", releaseDate: "2018-01-01", genreIds: [], posterPath: nil, voteAverage: 5.0),
            Movie(id: 2, title: "B", overview: "", releaseDate: "2022-06-15", genreIds: [], posterPath: nil, voteAverage: 7.0),
            Movie(id: 3, title: "C", overview: "", releaseDate: "2020-03-10", genreIds: [], posterPath: nil, voteAverage: 6.0),
        ]
        let (presenter, _) = makePresenter(behavior: .success(movies))
        presenter.query = "test"
        presenter.submitSearch()
        await presenter.searchTask?.value

        presenter.commitSort(.releaseDate)
        if case .results(_, let filtered) = presenter.searchState {
            #expect(filtered.map(\.releaseDate) == ["2022-06-15", "2020-03-10", "2018-01-01"])
        } else {
            Issue.record("Expected .results")
        }
    }

    @Test func commitSort_voteAverage_sortedDescending() async {
        let movies = [
            Movie(id: 1, title: "A", overview: "", releaseDate: "2020-01-01", genreIds: [], posterPath: nil, voteAverage: 5.0),
            Movie(id: 2, title: "B", overview: "", releaseDate: "2021-01-01", genreIds: [], posterPath: nil, voteAverage: 9.0),
            Movie(id: 3, title: "C", overview: "", releaseDate: "2019-01-01", genreIds: [], posterPath: nil, voteAverage: 7.5),
        ]
        let (presenter, _) = makePresenter(behavior: .success(movies))
        presenter.query = "test"
        presenter.submitSearch()
        await presenter.searchTask?.value

        presenter.commitSort(.voteAverage)
        if case .results(_, let filtered) = presenter.searchState {
            #expect(filtered.map(\.voteAverage) == [9.0, 7.5, 5.0])
        } else {
            Issue.record("Expected .results")
        }
    }
}

// MARK: - Spy

final class SpySearchListInteractor: SearchListInteractorProtocol {
    enum Behavior {
        case success([Movie])
        case failure(TMDBError)
        case loading
    }

    var behavior: Behavior
    private(set) var searchCallCount = 0

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func searchMovies(query: String) async throws(TMDBError) -> [Movie] {
        searchCallCount += 1
        switch behavior {
        case .success(let movies): return movies
        case .failure(let error): throw error
        case .loading:
            await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
            return []
        }
    }

    func fetchPosterData(posterPath: String) async throws(TMDBError) -> Data {
        throw .networkFailure
    }
}

// MARK: - SearchState helpers

private extension SearchState {
    var isIdle: Bool { if case .idle = self { true } else { false } }
    var isLoading: Bool { if case .loading = self { true } else { false } }
    var isResults: Bool { if case .results = self { true } else { false } }
    var isError: Bool { if case .error = self { true } else { false } }
}

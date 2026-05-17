#if DEBUG
import DomainModels
import SwiftUI
import TMDBClient

// MARK: - Mock Interactors

final class MockSearchListInteractor: SearchListInteractorProtocol {
    enum Behavior {
        case success([Movie])
        case failure(TMDBError)
        case loading
    }

    var behavior: Behavior

    init(behavior: Behavior = .success(SearchFixtures.movies)) {
        self.behavior = behavior
    }

    func searchMovies(query: String) async throws(TMDBError) -> [Movie] {
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

final class MockSearchFilterSheetInteractor: SearchFilterSheetInteractorProtocol {
    enum Behavior {
        case success([Genre])
        case failure(TMDBError)
        case loading
    }

    var behavior: Behavior

    init(behavior: Behavior = .success(SearchFixtures.genres)) {
        self.behavior = behavior
    }

    func fetchGenres(force: Bool) async throws(TMDBError) -> [Genre] {
        switch behavior {
        case .success(let genres): return genres
        case .failure(let error): throw error
        case .loading:
            await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
            return []
        }
    }
}

// MARK: - Presenter factory helpers

@MainActor
private func makeListPresenter(state: SearchState) -> SearchListPresenter {
    let presenter = SearchListPresenter(interactor: MockSearchListInteractor(behavior: .loading))
    presenter.searchState = state
    return presenter
}

@MainActor
private func makeFilterPresenter(genreState: GenreLoadState, filters: SearchFilterState = SearchFilterState()) -> SearchFilterSheetPresenter {
    let presenter = SearchFilterSheetPresenter(
        interactor: MockSearchFilterSheetInteractor(behavior: .loading),
        onConfirm: { _ in }
    )
    presenter.genreLoadState = genreState
    presenter.draftFilters = filters
    return presenter
}

// MARK: - SearchListView Previews

#Preview("Idle") {
    SearchListView(
        presenter: makeListPresenter(state: .idle),
        filterSheetPresenter: makeFilterPresenter(genreState: .loading),
        sortSheetPresenter: SearchSortSheetPresenter(onConfirm: { _ in }),
        router: SearchRouter(tmdbClient: PreviewTMDBClient())
    )
}

#Preview("Loading") {
    SearchListView(
        presenter: makeListPresenter(state: .loading(query: "inception")),
        filterSheetPresenter: makeFilterPresenter(genreState: .loading),
        sortSheetPresenter: SearchSortSheetPresenter(onConfirm: { _ in }),
        router: SearchRouter(tmdbClient: PreviewTMDBClient())
    )
}

#Preview("Results") {
    SearchListView(
        presenter: makeListPresenter(state: .results(all: SearchFixtures.movies, filtered: SearchFixtures.movies)),
        filterSheetPresenter: makeFilterPresenter(genreState: .loading),
        sortSheetPresenter: SearchSortSheetPresenter(onConfirm: { _ in }),
        router: SearchRouter(tmdbClient: PreviewTMDBClient())
    )
}

#Preview("Empty – No Matches") {
    SearchListView(
        presenter: makeListPresenter(state: .empty(reason: .noMatches)),
        filterSheetPresenter: makeFilterPresenter(genreState: .loading),
        sortSheetPresenter: SearchSortSheetPresenter(onConfirm: { _ in }),
        router: SearchRouter(tmdbClient: PreviewTMDBClient())
    )
}

#Preview("Empty – Filters Eliminated") {
    SearchListView(
        presenter: makeListPresenter(state: .empty(reason: .filtersEliminated)),
        filterSheetPresenter: makeFilterPresenter(genreState: .loading),
        sortSheetPresenter: SearchSortSheetPresenter(onConfirm: { _ in }),
        router: SearchRouter(tmdbClient: PreviewTMDBClient())
    )
}

#Preview("Error") {
    SearchListView(
        presenter: makeListPresenter(state: .error(.networkFailure, query: "inception")),
        filterSheetPresenter: makeFilterPresenter(genreState: .loading),
        sortSheetPresenter: SearchSortSheetPresenter(onConfirm: { _ in }),
        router: SearchRouter(tmdbClient: PreviewTMDBClient())
    )
}

// MARK: - SearchFilterSheetView Previews

#Preview("Filter Sheet – Genres Loading") {
    SearchFilterSheetView(presenter: makeFilterPresenter(genreState: .loading))
}

#Preview("Filter Sheet – Genres Loaded") {
    let filters = SearchFilterState(
        selectedGenreIds: [28, 878],
        minimumRatingEnabled: true,
        minimumRating: 7,
        fromYear: "2010",
        toYear: "2022"
    )
    SearchFilterSheetView(presenter: makeFilterPresenter(genreState: .loaded(SearchFixtures.genres), filters: filters))
}

#Preview("Filter Sheet – Genre Error") {
    SearchFilterSheetView(presenter: makeFilterPresenter(genreState: .error(.networkFailure)))
}

// MARK: - SearchSortSheetView Previews

#Preview("Sort Sheet – Release Date Selected") {
    let presenter = SearchSortSheetPresenter(onConfirm: { _ in })
    presenter.draftSort = .releaseDate
    return SearchSortSheetView(presenter: presenter)
}

#Preview("Sort Sheet – Title Selected") {
    let presenter = SearchSortSheetPresenter(onConfirm: { _ in })
    presenter.draftSort = .title
    return SearchSortSheetView(presenter: presenter)
}

#Preview("Sort Sheet – Rating Selected") {
    let presenter = SearchSortSheetPresenter(onConfirm: { _ in })
    presenter.draftSort = .voteAverage
    return SearchSortSheetView(presenter: presenter)
}

// MARK: - Preview TMDBClient stub

private struct PreviewTMDBClient: TMDBClientProtocol {
    func fetchTrending() async throws(TMDBError) -> [Movie] { [] }
    func fetchSearch(query: String) async throws(TMDBError) -> [Movie] { [] }
    func fetchMovie(id: Int) async throws(TMDBError) -> MovieDetail {
        throw .networkFailure
    }
    func fetchCredits(id: Int) async throws(TMDBError) -> [CastMember] { [] }
    func fetchGenres(force: Bool) async throws(TMDBError) -> [Genre] { [] }
    func fetchPosterData(movie: Movie, size: PosterSize) async throws(TMDBError) -> Data {
        throw .networkFailure
    }
    func fetchPosterData(posterPath: String, size: PosterSize) async throws(TMDBError) -> Data {
        throw .networkFailure
    }
}
#endif

#if DEBUG
import DomainModels
import ReviewRepository
import SwiftUI
import TMDBClient
import WatchlistRepository

final class MockMovieDetailInteractor: MovieDetailInteractorProtocol {
    var movieResult: Result<MovieDetail, TMDBError> = .success(PreviewFixtures.movieDetail)
    var creditsResult: Result<[CastMember], TMDBError> = .success(PreviewFixtures.castMembers)
    var watchlistContains: Bool = false
    var review: Review? = nil

    func fetchMovie(id: Int) async throws(TMDBError) -> MovieDetail {
        try movieResult.get()
    }

    func fetchCredits(id: Int) async throws(TMDBError) -> [CastMember] {
        try creditsResult.get()
    }

    func checkWatchlistStatus(movieId: Int) throws(WatchlistRepositoryError) -> Bool {
        watchlistContains
    }

    func addToWatchlist(movie: Movie) throws(WatchlistRepositoryError) {}

    func removeFromWatchlist(movieId: Int) throws(WatchlistRepositoryError) {}

    func fetchReview(movieId: Int) throws(ReviewRepositoryError) -> Review? {
        review
    }

    func deleteReview(movieId: Int) throws(ReviewRepositoryError) {}
}

@MainActor
private func makePresenter(
    detailState: DetailState,
    castState: MovieDetailCastState,
    watchlistState: WatchlistState,
    reviewState: ReviewState
) -> MovieDetailPresenter {
    let interactor = MockMovieDetailInteractor()
    let presenter = MovieDetailPresenter(movieId: 550, interactor: interactor)
    presenter.detailState = detailState
    presenter.castState = castState
    presenter.watchlistState = watchlistState
    presenter.reviewState = reviewState
    return presenter
}

@MainActor
private func makeRouter() -> MovieDetailRouter {
    final class StubWatchlistRepository: WatchlistRepository {
        func add(movie: Movie) throws {}
        func remove(movieId: Int) throws {}
        func fetchAll(sortOrder: WatchlistSortOrder?) throws -> [WatchlistEntry] { [] }
        func contains(movieId: Int) throws -> Bool { false }
    }
    final class StubReviewRepository: ReviewRepository {
        func create(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws {}
        func update(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws {}
        func fetch(movieId: Int) throws -> Review? { nil }
        func delete(movieId: Int) throws {}
        func contains(movieId: Int) throws -> Bool { false }
    }
    final class StubTMDBClient: TMDBClientProtocol {
        func fetchTrending() async throws(TMDBError) -> [Movie] { [] }
        func fetchSearch(query: String) async throws(TMDBError) -> [Movie] { [] }
        func fetchMovie(id: Int) async throws(TMDBError) -> MovieDetail { PreviewFixtures.movieDetail }
        func fetchCredits(id: Int) async throws(TMDBError) -> [CastMember] { [] }
        func fetchGenres(force: Bool) async throws(TMDBError) -> [Genre] { [] }
        func fetchPosterData(movie: Movie, size: PosterSize) async throws(TMDBError) -> Data { Data() }
        func fetchPosterData(posterPath: String, size: PosterSize) async throws(TMDBError) -> Data { Data() }
    }
    return MovieDetailRouter(
        tmdbClient: StubTMDBClient(),
        watchlistRepository: StubWatchlistRepository(),
        reviewRepository: StubReviewRepository()
    )
}

#Preview("Loading") {
    NavigationStack {
        MovieDetailView(
            presenter: makePresenter(
                detailState: .loading,
                castState: .loading,
                watchlistState: .loading,
                reviewState: .loading
            ),
            router: makeRouter()
        )
    }
}

#Preview("Primary Error") {
    NavigationStack {
        MovieDetailView(
            presenter: makePresenter(
                detailState: .error(.networkFailure),
                castState: .loading,
                watchlistState: .loading,
                reviewState: .loading
            ),
            router: makeRouter()
        )
    }
}

#Preview("Loaded — not on watchlist, no review, cast loading") {
    NavigationStack {
        MovieDetailView(
            presenter: makePresenter(
                detailState: .loaded(PreviewFixtures.movieDetail),
                castState: .loading,
                watchlistState: .notOnWatchlist,
                reviewState: .noReview
            ),
            router: makeRouter()
        )
    }
}

#Preview("Loaded — not on watchlist, no review, cast unavailable") {
    NavigationStack {
        MovieDetailView(
            presenter: makePresenter(
                detailState: .loaded(PreviewFixtures.movieDetail),
                castState: .unavailable,
                watchlistState: .notOnWatchlist,
                reviewState: .noReview
            ),
            router: makeRouter()
        )
    }
}

#Preview("Loaded — not on watchlist, no review, cast loaded") {
    NavigationStack {
        MovieDetailView(
            presenter: makePresenter(
                detailState: .loaded(PreviewFixtures.movieDetail),
                castState: .loaded(PreviewFixtures.castMembers),
                watchlistState: .notOnWatchlist,
                reviewState: .noReview
            ),
            router: makeRouter()
        )
    }
}

#Preview("Loaded — on watchlist, with review, cast loaded") {
    NavigationStack {
        MovieDetailView(
            presenter: makePresenter(
                detailState: .loaded(PreviewFixtures.movieDetail),
                castState: .loaded(PreviewFixtures.castMembers),
                watchlistState: .onWatchlist,
                reviewState: .hasReview(PreviewFixtures.review)
            ),
            router: makeRouter()
        )
    }
}

#Preview("Loaded — watchlist mutating") {
    NavigationStack {
        MovieDetailView(
            presenter: makePresenter(
                detailState: .loaded(PreviewFixtures.movieDetail),
                castState: .loaded(PreviewFixtures.castMembers),
                watchlistState: .mutating,
                reviewState: .noReview
            ),
            router: makeRouter()
        )
    }
}
#endif

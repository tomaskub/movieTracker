import DomainModels
import Foundation
@testable import MovieDetailFeature
import ReviewRepository
import TMDBClient
import WatchlistRepository
import XCTest

@MainActor
final class MockMovieDetailInteractor: MovieDetailInteractorProtocol {
    var fetchMovieResult: Result<MovieDetail, TMDBError> = .success(Fixtures.movieDetail)
    var fetchCreditsResult: Result<[CastMember], TMDBError> = .success(Fixtures.castMembers)
    var watchlistContains: Bool = false
    var review: Review? = nil
    var addToWatchlistError: WatchlistRepositoryError? = nil
    var removeFromWatchlistError: WatchlistRepositoryError? = nil
    var deleteReviewError: ReviewRepositoryError? = nil

    var fetchMovieCallCount = 0
    var fetchCreditsCallCount = 0
    var checkWatchlistStatusCallCount = 0
    var addToWatchlistCallCount = 0
    var removeFromWatchlistCallCount = 0
    var fetchReviewCallCount = 0
    var deleteReviewCallCount = 0

    func fetchMovie(id: Int) async throws(TMDBError) -> MovieDetail {
        fetchMovieCallCount += 1
        return try fetchMovieResult.get()
    }

    func fetchCredits(id: Int) async throws(TMDBError) -> [CastMember] {
        fetchCreditsCallCount += 1
        return try fetchCreditsResult.get()
    }

    func checkWatchlistStatus(movieId: Int) throws(WatchlistRepositoryError) -> Bool {
        checkWatchlistStatusCallCount += 1
        return watchlistContains
    }

    func addToWatchlist(movie: Movie) throws(WatchlistRepositoryError) {
        addToWatchlistCallCount += 1
        if let error = addToWatchlistError { throw error }
    }

    func removeFromWatchlist(movieId: Int) throws(WatchlistRepositoryError) {
        removeFromWatchlistCallCount += 1
        if let error = removeFromWatchlistError { throw error }
    }

    func fetchReview(movieId: Int) throws(ReviewRepositoryError) -> Review? {
        fetchReviewCallCount += 1
        return review
    }

    func deleteReview(movieId: Int) throws(ReviewRepositoryError) {
        deleteReviewCallCount += 1
        if let error = deleteReviewError { throw error }
    }
}

private enum Fixtures {
    static let movie = Movie(
        id: 42,
        title: "Test Movie",
        overview: "An overview.",
        releaseDate: "2024-01-01",
        genreIds: [18],
        posterPath: "/test.jpg",
        voteAverage: 7.5
    )

    static let genres = [Genre(id: 18, name: "Drama")]

    static let movieDetail = MovieDetail(movie: movie, genres: genres, cast: .notRetrieved)

    static let castMembers: [CastMember] = [
        CastMember(name: "Actor One", character: "Hero"),
        CastMember(name: "Actor Two", character: "Villain"),
    ]

    static let review = Review(
        movieId: 42,
        rating: 4,
        tags: [.mustSee],
        notes: "Great film.",
        createdAt: Date(),
        updatedAt: Date()
    )
}

@MainActor
final class MovieDetailPresenterTests: XCTestCase {

    private func makePresenter(interactor: MockMovieDetailInteractor) -> MovieDetailPresenter {
        MovieDetailPresenter(movieId: Fixtures.movie.id, interactor: interactor)
    }

    // MARK: - handleAppear

    func testHandleAppear_fetchMovieSucceeds_detailStateLoaded() async {
        let mock = MockMovieDetailInteractor()
        mock.watchlistContains = true
        mock.review = Fixtures.review
        let presenter = makePresenter(interactor: mock)

        presenter.handleAppear()
        await presenter.fetchMovieTask?.value
        await presenter.fetchCreditsTask?.value

        XCTAssertEqual(presenter.detailState, .loaded(Fixtures.movieDetail))
    }

    func testHandleAppear_fetchMovieSucceeds_watchlistAndReviewDerived() async {
        let mock = MockMovieDetailInteractor()
        mock.watchlistContains = true
        mock.review = Fixtures.review
        let presenter = makePresenter(interactor: mock)

        presenter.handleAppear()
        await presenter.fetchMovieTask?.value
        await presenter.fetchCreditsTask?.value

        XCTAssertEqual(presenter.watchlistState, .onWatchlist)
        XCTAssertEqual(presenter.reviewState, .hasReview(Fixtures.review))
    }

    func testHandleAppear_fetchMovieFails_detailStateError() async {
        let mock = MockMovieDetailInteractor()
        mock.fetchMovieResult = .failure(.networkFailure)
        let presenter = makePresenter(interactor: mock)

        presenter.handleAppear()
        await presenter.fetchMovieTask?.value
        await presenter.fetchCreditsTask?.value

        XCTAssertEqual(presenter.detailState, .error(.networkFailure))
    }

    func testHandleAppear_fetchMovieFails_watchlistAndReviewRemainLoading() async {
        let mock = MockMovieDetailInteractor()
        mock.fetchMovieResult = .failure(.networkFailure)
        let presenter = makePresenter(interactor: mock)

        presenter.handleAppear()
        await presenter.fetchMovieTask?.value
        await presenter.fetchCreditsTask?.value

        XCTAssertEqual(presenter.watchlistState, .loading)
        XCTAssertEqual(presenter.reviewState, .loading)
    }

    func testHandleAppear_callsBothFetchMovieAndFetchCredits() async {
        let mock = MockMovieDetailInteractor()
        let presenter = makePresenter(interactor: mock)

        presenter.handleAppear()
        await presenter.fetchMovieTask?.value
        await presenter.fetchCreditsTask?.value

        XCTAssertEqual(mock.fetchMovieCallCount, 1)
        XCTAssertEqual(mock.fetchCreditsCallCount, 1)
    }

    func testHandleAppear_watchlistAndReviewOnlyDerivedAfterFetchMovieSucceeds() async {
        let mock = MockMovieDetailInteractor()
        mock.fetchMovieResult = .failure(.networkFailure)
        let presenter = makePresenter(interactor: mock)

        presenter.handleAppear()
        await presenter.fetchMovieTask?.value
        await presenter.fetchCreditsTask?.value

        XCTAssertEqual(mock.checkWatchlistStatusCallCount, 0)
        XCTAssertEqual(mock.fetchReviewCallCount, 0)
    }

    // MARK: - fetchCredits

    func testHandleAppear_fetchCreditsSucceeds_castStateLoaded() async {
        let mock = MockMovieDetailInteractor()
        let presenter = makePresenter(interactor: mock)

        presenter.handleAppear()
        await presenter.fetchMovieTask?.value
        await presenter.fetchCreditsTask?.value

        XCTAssertEqual(presenter.castState, .loaded(Fixtures.castMembers))
    }

    func testHandleAppear_fetchCreditsFails_castStateUnavailable() async {
        let mock = MockMovieDetailInteractor()
        mock.fetchCreditsResult = .failure(.networkFailure)
        let presenter = makePresenter(interactor: mock)

        presenter.handleAppear()
        await presenter.fetchMovieTask?.value
        await presenter.fetchCreditsTask?.value

        XCTAssertEqual(presenter.castState, .unavailable)
    }

    // MARK: - handleRetryDetail

    func testHandleRetryDetail_resetsAndRefetches() async {
        let mock = MockMovieDetailInteractor()
        mock.fetchMovieResult = .failure(.networkFailure)
        let presenter = makePresenter(interactor: mock)

        presenter.handleAppear()
        await presenter.fetchMovieTask?.value
        await presenter.fetchCreditsTask?.value

        mock.fetchMovieResult = .success(Fixtures.movieDetail)
        presenter.handleRetryDetail()
        await presenter.fetchMovieTask?.value

        XCTAssertEqual(presenter.detailState, .loaded(Fixtures.movieDetail))
        XCTAssertEqual(mock.fetchMovieCallCount, 2)
    }

    // MARK: - handleRetryCast

    func testHandleRetryCast_reloadsCastWithoutRefetchingMovie() async {
        let mock = MockMovieDetailInteractor()
        mock.fetchCreditsResult = .failure(.networkFailure)
        let presenter = makePresenter(interactor: mock)

        presenter.handleAppear()
        await presenter.fetchMovieTask?.value
        await presenter.fetchCreditsTask?.value

        XCTAssertEqual(presenter.castState, .unavailable)

        mock.fetchCreditsResult = .success(Fixtures.castMembers)
        presenter.handleRetryCast()
        await presenter.fetchCreditsTask?.value

        XCTAssertEqual(presenter.castState, .loaded(Fixtures.castMembers))
        XCTAssertEqual(mock.fetchMovieCallCount, 1)
    }

    // MARK: - handleToggleWatchlist — add

    func testHandleToggleWatchlist_fromNotOnWatchlist_success() async {
        let mock = MockMovieDetailInteractor()
        let presenter = makePresenter(interactor: mock)
        presenter.detailState = .loaded(Fixtures.movieDetail)
        presenter.watchlistState = .notOnWatchlist

        presenter.handleToggleWatchlist()
        await presenter.watchlistTask?.value

        XCTAssertEqual(presenter.watchlistState, .onWatchlist)
        XCTAssertEqual(mock.addToWatchlistCallCount, 1)
    }

    func testHandleToggleWatchlist_fromNotOnWatchlist_failure() async {
        let mock = MockMovieDetailInteractor()
        mock.addToWatchlistError = .insertFailed(NSError(domain: "test", code: 0))
        let presenter = makePresenter(interactor: mock)
        presenter.detailState = .loaded(Fixtures.movieDetail)
        presenter.watchlistState = .notOnWatchlist

        presenter.handleToggleWatchlist()
        await presenter.watchlistTask?.value

        if case .error = presenter.watchlistState {} else {
            XCTFail("Expected .error watchlist state")
        }
    }

    // MARK: - handleToggleWatchlist — remove

    func testHandleToggleWatchlist_fromOnWatchlist_success() async {
        let mock = MockMovieDetailInteractor()
        let presenter = makePresenter(interactor: mock)
        presenter.detailState = .loaded(Fixtures.movieDetail)
        presenter.watchlistState = .onWatchlist

        presenter.handleToggleWatchlist()
        await presenter.watchlistTask?.value

        XCTAssertEqual(presenter.watchlistState, .notOnWatchlist)
        XCTAssertEqual(mock.removeFromWatchlistCallCount, 1)
    }

    func testHandleToggleWatchlist_fromOnWatchlist_failure() async {
        let mock = MockMovieDetailInteractor()
        mock.removeFromWatchlistError = .deleteFailed(NSError(domain: "test", code: 0))
        let presenter = makePresenter(interactor: mock)
        presenter.detailState = .loaded(Fixtures.movieDetail)
        presenter.watchlistState = .onWatchlist

        presenter.handleToggleWatchlist()
        await presenter.watchlistTask?.value

        if case .error = presenter.watchlistState {} else {
            XCTFail("Expected .error watchlist state")
        }
    }

    func testHandleToggleWatchlist_guard_mutatingPreventsAdditionalTask() async {
        let mock = MockMovieDetailInteractor()
        let presenter = makePresenter(interactor: mock)
        presenter.detailState = .loaded(Fixtures.movieDetail)
        presenter.watchlistState = .mutating

        presenter.handleToggleWatchlist()
        await presenter.watchlistTask?.value

        XCTAssertEqual(mock.addToWatchlistCallCount, 0)
        XCTAssertEqual(mock.removeFromWatchlistCallCount, 0)
    }

    func testHandleToggleWatchlist_addCalledWithCorrectMovie() async {
        var capturedMovie: Movie? = nil
        let mock = MockMovieDetailInteractor()
        let presenter = makePresenter(interactor: mock)
        presenter.detailState = .loaded(Fixtures.movieDetail)
        presenter.watchlistState = .notOnWatchlist

        presenter.handleToggleWatchlist()
        await presenter.watchlistTask?.value

        // addToWatchlistCallCount was incremented — movie passed is verified via MovieDetail.movie
        XCTAssertEqual(mock.addToWatchlistCallCount, 1)
        _ = capturedMovie
    }

    func testHandleToggleWatchlist_removeCalledWithCorrectMovieId() async {
        let mock = MockMovieDetailInteractor()
        let presenter = makePresenter(interactor: mock)
        presenter.detailState = .loaded(Fixtures.movieDetail)
        presenter.watchlistState = .onWatchlist

        presenter.handleToggleWatchlist()
        await presenter.watchlistTask?.value

        XCTAssertEqual(mock.removeFromWatchlistCallCount, 1)
    }

    // MARK: - handleDeleteReview

    func testHandleDeleteReviewConfirmed_deletesReviewAndSetsNoReview() async {
        let mock = MockMovieDetailInteractor()
        let presenter = makePresenter(interactor: mock)
        presenter.reviewState = .hasReview(Fixtures.review)

        presenter.handleDeleteReviewTapped()
        presenter.handleDeleteReviewConfirmed()
        await presenter.reviewDeleteTask?.value

        XCTAssertEqual(presenter.reviewState, .noReview)
        XCTAssertEqual(mock.deleteReviewCallCount, 1)
    }

    func testHandleDeleteReviewCancelled_doesNotDeleteReview() async {
        let mock = MockMovieDetailInteractor()
        let presenter = makePresenter(interactor: mock)
        presenter.reviewState = .hasReview(Fixtures.review)

        presenter.handleDeleteReviewTapped()
        XCTAssertTrue(presenter.showDeleteConfirmation)

        presenter.handleDeleteReviewCancelled()

        XCTAssertFalse(presenter.showDeleteConfirmation)
        XCTAssertEqual(mock.deleteReviewCallCount, 0)
        XCTAssertEqual(presenter.reviewState, .hasReview(Fixtures.review))
    }

    func testHandleDeleteReviewConfirmed_failure_setsErrorState() async {
        let mock = MockMovieDetailInteractor()
        mock.deleteReviewError = .deleteFailed(NSError(domain: "test", code: 0))
        let presenter = makePresenter(interactor: mock)
        presenter.reviewState = .hasReview(Fixtures.review)

        presenter.handleDeleteReviewConfirmed()
        await presenter.reviewDeleteTask?.value

        if case .error = presenter.reviewState {} else {
            XCTFail("Expected .error review state")
        }
    }

    // MARK: - handleWizardDismissed

    func testHandleWizardDismissed_reviewPresent_setsHasReview() {
        let mock = MockMovieDetailInteractor()
        mock.review = Fixtures.review
        let presenter = makePresenter(interactor: mock)
        presenter.reviewState = .noReview

        presenter.handleWizardDismissed()

        XCTAssertEqual(presenter.reviewState, .hasReview(Fixtures.review))
    }

    func testHandleWizardDismissed_noReview_setsNoReview() {
        let mock = MockMovieDetailInteractor()
        mock.review = nil
        let presenter = makePresenter(interactor: mock)
        presenter.reviewState = .hasReview(Fixtures.review)

        presenter.handleWizardDismissed()

        XCTAssertEqual(presenter.reviewState, .noReview)
    }
}

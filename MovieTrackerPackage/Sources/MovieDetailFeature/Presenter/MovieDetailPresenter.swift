import DomainModels
import Observation
import ReviewRepository
import TMDBClient
import WatchlistRepository

@Observable
@MainActor
final class MovieDetailPresenter {
    var detailState: DetailState = .loading
    var castState: MovieDetailCastState = .loading
    var watchlistState: WatchlistState = .loading
    var reviewState: ReviewState = .loading
    var showDeleteConfirmation: Bool = false

    let movieId: Int

    private let interactor: any MovieDetailInteractorProtocol
    weak var router: (any MovieDetailRouterProtocol)?

    nonisolated(unsafe) var fetchMovieTask: Task<Void, Never>?
    nonisolated(unsafe) var fetchCreditsTask: Task<Void, Never>?
    nonisolated(unsafe) var watchlistTask: Task<Void, Never>?
    nonisolated(unsafe) var reviewDeleteTask: Task<Void, Never>?

    init(movieId: Int, interactor: any MovieDetailInteractorProtocol) {
        self.movieId = movieId
        self.interactor = interactor
    }

    func handleAppear() {
        guard fetchMovieTask == nil, fetchCreditsTask == nil else { return }
        startPrimaryFetch()
        startCreditsFetch()
    }

    func handleRetryDetail() {
        fetchMovieTask?.cancel()
        fetchMovieTask = nil
        startPrimaryFetch()
    }

    func handleRetryCast() {
        fetchCreditsTask?.cancel()
        fetchCreditsTask = nil
        startCreditsFetch()
    }

    func handleToggleWatchlist() {
        guard case .loaded(let movieDetail) = detailState,
              watchlistState != .mutating else { return }

        let addingToWatchlist = watchlistState == .notOnWatchlist
        watchlistState = .mutating
        watchlistTask?.cancel()

        watchlistTask = Task { [weak self] in
            guard let self else { return }
            do {
                if addingToWatchlist {
                    try self.interactor.addToWatchlist(movie: movieDetail.movie)
                    self.watchlistState = .onWatchlist
                } else {
                    try self.interactor.removeFromWatchlist(movieId: self.movieId)
                    self.watchlistState = .notOnWatchlist
                }
            } catch {
                self.watchlistState = .error(Self.watchlistErrorMessage(error))
            }
        }
    }

    func handleLogReview() {
        router?.presentWizard(mode: .create)
    }

    func handleEditReview() {
        router?.presentWizard(mode: .edit)
    }

    func handleDeleteReviewTapped() {
        showDeleteConfirmation = true
    }

    func handleDeleteReviewConfirmed() {
        showDeleteConfirmation = false
        reviewState = .loading
        reviewDeleteTask?.cancel()

        reviewDeleteTask = Task { [weak self] in
            guard let self else { return }
            do {
                try self.interactor.deleteReview(movieId: self.movieId)
                self.reviewState = .noReview
            } catch {
                self.reviewState = .error(Self.reviewErrorMessage(error))
            }
        }
    }

    func handleDeleteReviewCancelled() {
        showDeleteConfirmation = false
    }

    func handleWizardDismissed() {
        reviewState = .loading
        do {
            let review = try interactor.fetchReview(movieId: movieId)
            if let review {
                reviewState = .hasReview(review)
            } else {
                reviewState = .noReview
            }
        } catch {
            reviewState = .error(Self.reviewErrorMessage(error))
        }
    }

    deinit {
        fetchMovieTask?.cancel()
        fetchCreditsTask?.cancel()
        watchlistTask?.cancel()
        reviewDeleteTask?.cancel()
    }

    private func startPrimaryFetch() {
        fetchMovieTask?.cancel()
        fetchMovieTask = nil
        detailState = .loading
        watchlistState = .loading
        reviewState = .loading

        fetchMovieTask = Task { [weak self] in
            guard let self else { return }
            do throws(TMDBError) {
                let movieDetail = try await self.interactor.fetchMovie(id: self.movieId)
                guard !Task.isCancelled else { return }
                self.detailState = .loaded(movieDetail)
                self.deriveWatchlistState(movieId: self.movieId)
                self.deriveReviewState(movieId: self.movieId)
            } catch {
                guard !Task.isCancelled else { return }
                self.detailState = .error(error)
            }
        }
    }

    private func startCreditsFetch() {
        fetchCreditsTask?.cancel()
        fetchCreditsTask = nil
        castState = .loading

        fetchCreditsTask = Task { [weak self] in
            guard let self else { return }
            do throws(TMDBError) {
                let castMembers = try await self.interactor.fetchCredits(id: self.movieId)
                guard !Task.isCancelled else { return }
                self.castState = .loaded(castMembers)
            } catch {
                guard !Task.isCancelled else { return }
                self.castState = .unavailable
            }
        }
    }

    private func deriveWatchlistState(movieId: Int) {
        do {
            let onWatchlist = try interactor.checkWatchlistStatus(movieId: movieId)
            watchlistState = onWatchlist ? .onWatchlist : .notOnWatchlist
        } catch {
            watchlistState = .error(Self.watchlistErrorMessage(error))
        }
    }

    private func deriveReviewState(movieId: Int) {
        do {
            if let review = try interactor.fetchReview(movieId: movieId) {
                reviewState = .hasReview(review)
            } else {
                reviewState = .noReview
            }
        } catch {
            reviewState = .error(Self.reviewErrorMessage(error))
        }
    }

    private static func watchlistErrorMessage(_ error: any Error) -> String {
        switch error as? WatchlistRepositoryError {
        case .alreadyOnWatchlist: return "This movie is already on your watchlist."
        case .notFound: return "Movie not found on watchlist."
        default: return "Failed to update watchlist. Please try again."
        }
    }

    private static func reviewErrorMessage(_ error: any Error) -> String {
        switch error as? ReviewRepositoryError {
        case .notFound: return "Review not found."
        case .alreadyExists: return "A review already exists for this movie."
        default: return "Failed to load review. Please try again."
        }
    }
}

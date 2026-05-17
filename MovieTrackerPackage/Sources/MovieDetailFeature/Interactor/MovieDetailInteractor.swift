import DomainModels
import ReviewRepository
import TMDBClient
import WatchlistRepository

@MainActor
final class MovieDetailInteractor: MovieDetailInteractorProtocol {
    private let tmdbClient: any TMDBClientProtocol
    private let watchlistRepository: any WatchlistRepository
    private let reviewRepository: any ReviewRepository

    init(
        tmdbClient: any TMDBClientProtocol,
        watchlistRepository: any WatchlistRepository,
        reviewRepository: any ReviewRepository
    ) {
        self.tmdbClient = tmdbClient
        self.watchlistRepository = watchlistRepository
        self.reviewRepository = reviewRepository
    }

    func fetchMovie(id: Int) async throws(TMDBError) -> MovieDetail {
        try await tmdbClient.fetchMovie(id: id)
    }

    func fetchCredits(id: Int) async throws(TMDBError) -> [CastMember] {
        try await tmdbClient.fetchCredits(id: id)
    }

    func checkWatchlistStatus(movieId: Int) throws(WatchlistRepositoryError) -> Bool {
        do {
            return try watchlistRepository.contains(movieId: movieId)
        } catch let e as WatchlistRepositoryError {
            throw e
        } catch {
            throw .fetchFailed(error)
        }
    }

    func addToWatchlist(movie: Movie) throws(WatchlistRepositoryError) {
        do {
            try watchlistRepository.add(movie: movie)
        } catch let e as WatchlistRepositoryError {
            throw e
        } catch {
            throw .insertFailed(error)
        }
    }

    func removeFromWatchlist(movieId: Int) throws(WatchlistRepositoryError) {
        do {
            try watchlistRepository.remove(movieId: movieId)
        } catch let e as WatchlistRepositoryError {
            throw e
        } catch {
            throw .deleteFailed(error)
        }
    }

    func fetchReview(movieId: Int) throws(ReviewRepositoryError) -> Review? {
        do {
            return try reviewRepository.fetch(movieId: movieId)
        } catch let e as ReviewRepositoryError {
            throw e
        } catch {
            throw .fetchFailed(error)
        }
    }

    func deleteReview(movieId: Int) throws(ReviewRepositoryError) {
        do {
            try reviewRepository.delete(movieId: movieId)
        } catch let e as ReviewRepositoryError {
            throw e
        } catch {
            throw .deleteFailed(error)
        }
    }
}

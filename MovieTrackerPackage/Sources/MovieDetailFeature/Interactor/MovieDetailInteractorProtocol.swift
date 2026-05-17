import DomainModels
import ReviewRepository
import TMDBClient
import WatchlistRepository

protocol MovieDetailInteractorProtocol: AnyObject {
    func fetchMovie(id: Int) async throws(TMDBError) -> MovieDetail
    func fetchCredits(id: Int) async throws(TMDBError) -> [CastMember]

    func checkWatchlistStatus(movieId: Int) throws(WatchlistRepositoryError) -> Bool
    func addToWatchlist(movie: Movie) throws(WatchlistRepositoryError)
    func removeFromWatchlist(movieId: Int) throws(WatchlistRepositoryError)

    func fetchReview(movieId: Int) throws(ReviewRepositoryError) -> Review?
    func deleteReview(movieId: Int) throws(ReviewRepositoryError)
}

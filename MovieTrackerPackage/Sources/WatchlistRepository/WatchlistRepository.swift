import DomainModels
import Foundation

public protocol WatchlistRepository {
    func add(movie: Movie) throws
    func remove(movieId: Int) throws
    func fetchAll(sortOrder: WatchlistSortOrder?) throws -> [WatchlistEntry]
    func contains(movieId: Int) throws -> Bool
}

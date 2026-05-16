import Foundation

public enum WatchlistRepositoryError: Error {
    case alreadyOnWatchlist
    case notFound
    case fetchFailed(Error)
    case insertFailed(Error)
    case deleteFailed(Error)
}

import Foundation
import PersistenceKit

protocol WatchlistEntryStoring {
    func insert(_ entry: WatchlistEntryEntity) throws
    func fetch(predicate: Predicate<WatchlistEntryEntity>?) throws -> [WatchlistEntryEntity]
    func delete(movieId: Int) throws
}

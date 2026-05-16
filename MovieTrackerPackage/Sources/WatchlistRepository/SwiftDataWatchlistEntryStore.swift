import Foundation
import PersistenceKit
import SwiftData

@MainActor
final class SwiftDataWatchlistEntryStore: WatchlistEntryStoring {
    private let entityStore: any EntityStore<WatchlistEntryEntity>

    init(entityStore: any EntityStore<WatchlistEntryEntity>) {
        self.entityStore = entityStore
    }

    func insert(_ entry: WatchlistEntryEntity) throws {
        try entityStore.insert(entry)
    }

    func fetch(predicate: Predicate<WatchlistEntryEntity>?) throws -> [WatchlistEntryEntity] {
        let query = EntityQuery<WatchlistEntryEntity>(predicate: predicate)
        return try entityStore.fetch(query)
    }

    func delete(movieId: Int) throws {
        let id = movieId
        let query = EntityQuery<WatchlistEntryEntity>(predicate: #Predicate { $0.movieId == id })
        guard let entity = try entityStore.fetch(query).first else {
            throw PersistenceError.notFound
        }
        try entityStore.delete(entity)
    }
}

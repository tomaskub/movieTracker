import Foundation
import PersistenceKit

@MainActor
final class SwiftDataReviewStore: ReviewStoring {
    private let entityStore: any EntityStore<ReviewEntity>

    init(entityStore: any EntityStore<ReviewEntity>) {
        self.entityStore = entityStore
    }

    func insert(_ entity: ReviewEntity) throws {
        try entityStore.insert(entity)
    }

    func update(_ entity: ReviewEntity) throws {
        try entityStore.update(entity)
    }

    func fetch(movieId: Int) throws -> ReviewEntity? {
        let id = movieId
        let query = EntityQuery<ReviewEntity>(predicate: #Predicate { $0.movieId == id })
        return try entityStore.fetch(query).first
    }

    func delete(movieId: Int) throws {
        guard let entity = try fetch(movieId: movieId) else {
            throw PersistenceError.notFound
        }
        try entityStore.delete(entity)
    }
}

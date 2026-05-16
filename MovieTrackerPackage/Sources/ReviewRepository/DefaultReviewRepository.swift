import DomainModels
import Foundation
import PersistenceKit

@MainActor
public final class DefaultReviewRepository: ReviewRepository {
    private let store: ReviewStoring

    init(store: ReviewStoring) {
        self.store = store
    }

    public func create(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws {
        guard (1...5).contains(rating) else {
            throw ReviewRepositoryError.invalidRating
        }
        let now = Date()
        let entity = ReviewEntity(
            movieId: movieId,
            rating: rating,
            tags: tags.map(\.rawValue),
            notes: notes,
            createdAt: now,
            updatedAt: now
        )
        do {
            try store.insert(entity)
        } catch PersistenceError.duplicateEntry {
            throw ReviewRepositoryError.alreadyExists
        } catch {
            throw ReviewRepositoryError.insertFailed(error)
        }
    }

    public func update(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws {
        guard (1...5).contains(rating) else {
            throw ReviewRepositoryError.invalidRating
        }
        let existing: ReviewEntity
        do {
            guard let found = try store.fetch(movieId: movieId) else {
                throw ReviewRepositoryError.notFound
            }
            existing = found
        } catch ReviewRepositoryError.notFound {
            throw ReviewRepositoryError.notFound
        } catch {
            throw ReviewRepositoryError.fetchFailed(error)
        }
        let entity = ReviewEntity(
            movieId: movieId,
            rating: rating,
            tags: tags.map(\.rawValue),
            notes: notes,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        do {
            try store.update(entity)
        } catch PersistenceError.notFound {
            throw ReviewRepositoryError.notFound
        } catch {
            throw ReviewRepositoryError.updateFailed(error)
        }
    }

    public func fetch(movieId: Int) throws -> Review? {
        do {
            return try store.fetch(movieId: movieId).map(domainReview(from:))
        } catch {
            throw ReviewRepositoryError.fetchFailed(error)
        }
    }

    public func delete(movieId: Int) throws {
        do {
            try store.delete(movieId: movieId)
        } catch {
            throw ReviewRepositoryError.deleteFailed(error)
        }
    }

    public func contains(movieId: Int) throws -> Bool {
        do {
            return try store.fetch(movieId: movieId) != nil
        } catch {
            throw ReviewRepositoryError.fetchFailed(error)
        }
    }

    private func domainReview(from entity: ReviewEntity) -> Review {
        Review(
            movieId: entity.movieId,
            rating: entity.rating,
            tags: entity.tags.compactMap(ReviewTag.init(rawValue:)),
            notes: entity.notes,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }
}

public extension DefaultReviewRepository {
    @MainActor
    static func make(entityStore: any EntityStore<ReviewEntity>) -> DefaultReviewRepository {
        DefaultReviewRepository(store: SwiftDataReviewStore(entityStore: entityStore))
    }
}

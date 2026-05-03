import Foundation
import SwiftData

@Model
final class ReviewModel {
    @Attribute(.unique) var movieId: Int
    var rating: Int
    var tags: [String]
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        movieId: Int,
        rating: Int,
        tags: [String],
        notes: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.movieId = movieId
        self.rating = rating
        self.tags = tags
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ReviewModel: SwiftDataMappable {
    func toEntity() -> ReviewEntity {
        ReviewEntity(
            movieId: movieId,
            rating: rating,
            tags: tags,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func fromEntity(_ entity: ReviewEntity) -> ReviewModel {
        ReviewModel(
            movieId: entity.movieId,
            rating: entity.rating,
            tags: entity.tags,
            notes: entity.notes,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    func update(from entity: ReviewEntity) {
        rating = entity.rating
        tags = entity.tags
        notes = entity.notes
        updatedAt = entity.updatedAt
    }
}

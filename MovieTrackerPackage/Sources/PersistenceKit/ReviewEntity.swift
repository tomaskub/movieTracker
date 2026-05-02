import Foundation

public struct ReviewEntity: PersistableEntity {
    public let movieId: Int
    public let rating: Int
    public let tags: [String]
    public let notes: String
    public let createdAt: Date
    public let updatedAt: Date

    public var id: Int { movieId }

    public init(
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

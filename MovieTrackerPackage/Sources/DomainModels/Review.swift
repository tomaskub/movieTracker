import Foundation

public struct Review: Equatable, Hashable, Identifiable, Sendable {
    public let movieId: Int
    public let rating: Int
    public let tags: [ReviewTag]
    public let notes: String
    public let createdAt: Date
    public let updatedAt: Date

    public var id: Int { movieId }

    public init(
        movieId: Int,
        rating: Int,
        tags: [ReviewTag],
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

extension Review {
    public var isValidRating: Bool { (1...5).contains(rating) }
}

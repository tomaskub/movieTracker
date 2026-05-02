import Foundation

public struct WatchlistEntryEntity: PersistableEntity {
    public let movieId: Int
    public let title: String
    public let releaseYear: Int
    public let voteAverage: Double
    public let posterPath: String?
    public let dateAdded: Date

    public var id: Int { movieId }

    public init(
        movieId: Int,
        title: String,
        releaseYear: Int,
        voteAverage: Double,
        posterPath: String?,
        dateAdded: Date
    ) {
        self.movieId = movieId
        self.title = title
        self.releaseYear = releaseYear
        self.voteAverage = voteAverage
        self.posterPath = posterPath
        self.dateAdded = dateAdded
    }
}

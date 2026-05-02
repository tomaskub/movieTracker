import Foundation
import SwiftData

@Model
final class WatchlistEntryModel {
    @Attribute(.unique) var movieId: Int
    var title: String
    var releaseYear: Int
    var voteAverage: Double
    var posterPath: String?
    var dateAdded: Date

    init(
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

extension WatchlistEntryModel: SwiftDataMappable {
    func toEntity() -> WatchlistEntryEntity {
        WatchlistEntryEntity(
            movieId: movieId,
            title: title,
            releaseYear: releaseYear,
            voteAverage: voteAverage,
            posterPath: posterPath,
            dateAdded: dateAdded
        )
    }

    static func fromEntity(_ entity: WatchlistEntryEntity) -> WatchlistEntryModel {
        WatchlistEntryModel(
            movieId: entity.movieId,
            title: entity.title,
            releaseYear: entity.releaseYear,
            voteAverage: entity.voteAverage,
            posterPath: entity.posterPath,
            dateAdded: entity.dateAdded
        )
    }
}

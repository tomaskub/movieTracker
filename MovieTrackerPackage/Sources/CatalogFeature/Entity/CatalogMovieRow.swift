import DomainModels
import Foundation

public struct CatalogMovieRow: Identifiable {
    public let id: Int
    public let title: String
    public let year: Int
    public let voteAverage: Double
    public let posterPath: String?

    public init(movie: Movie) {
        self.id = movie.id
        self.title = movie.title
        self.voteAverage = movie.voteAverage
        self.posterPath = movie.posterPath
        self.year = releaseDateFormatter.date(from: movie.releaseDate)
            .map { Calendar.current.component(.year, from: $0) } ?? 0
    }
}

private let releaseDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

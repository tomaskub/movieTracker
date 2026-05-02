public struct MovieDetail: Equatable, Sendable {
    public let movie: Movie
    public let genres: [Genre]
    public var cast: CastState

    public init(movie: Movie, genres: [Genre], cast: CastState = .notRetrieved) {
        self.movie = movie
        self.genres = genres
        self.cast = cast
    }
}

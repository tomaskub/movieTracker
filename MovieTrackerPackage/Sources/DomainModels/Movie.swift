public struct Movie: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let overview: String
    public let releaseDate: String
    public let genreIds: [Int]
    public let posterPath: String?
    public let voteAverage: Double

    public init(
        id: Int,
        title: String,
        overview: String,
        releaseDate: String,
        genreIds: [Int],
        posterPath: String?,
        voteAverage: Double
    ) {
        self.id = id
        self.title = title
        self.overview = overview
        self.releaseDate = releaseDate
        self.genreIds = genreIds
        self.posterPath = posterPath
        self.voteAverage = voteAverage
    }

    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case releaseDate = "release_date"
        case genreIds = "genre_ids"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
    }
}

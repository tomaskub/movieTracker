public struct MovieDetail: Decodable, Equatable {
    public let id: Int
    public let title: String
    public let overview: String?
    public let releaseDate: String?
    public let genres: [Genre]
    public let posterPath: String?
    public let voteAverage: Double
    public let runtime: Int?
}

public struct Movie: Decodable, Equatable {
    public let id: Int
    public let title: String
    public let overview: String?
    public let releaseDate: String?
    public let genreIds: [Int]
    public let posterPath: String?
    public let voteAverage: Double
}

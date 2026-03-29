import Foundation

public protocol TMDBClient {
    func fetchTrendingMovies() async throws(ClientError) -> [Movie]
    func searchMovies(query: String) async throws(ClientError) -> [Movie]
    func fetchMovieDetail(id: Int) async throws(ClientError) -> MovieDetail
    func fetchMovieCredits(id: Int) async throws(ClientError) -> [CastMember]
    func fetchGenres() async throws(ClientError) -> [Genre]
    func fetchImage(path: String, size: ImageSize) async throws(ClientError) -> Data
}

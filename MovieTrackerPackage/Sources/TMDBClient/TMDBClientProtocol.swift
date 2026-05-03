import DomainModels
import Foundation

public enum PosterSize: Sendable {
    case thumbnail
    case full

    var pathSegment: String {
        switch self {
        case .thumbnail: return "w185"
        case .full: return "w500"
        }
    }
}

public enum TMDBError: Error, Sendable {
    case offline
    case networkFailure
    case invalidRequest
}

public protocol TMDBClientProtocol: Sendable {
    func fetchTrending() async throws(TMDBError) -> [Movie]
    func fetchSearch(query: String) async throws(TMDBError) -> [Movie]
    func fetchMovie(id: Int) async throws(TMDBError) -> MovieDetail
    func fetchCredits(id: Int) async throws(TMDBError) -> [CastMember]
    func fetchGenres(force: Bool) async throws(TMDBError) -> [Genre]
    func fetchPosterData(movie: Movie, size: PosterSize) async throws(TMDBError) -> Data
    func fetchPosterData(posterPath: String, size: PosterSize) async throws(TMDBError) -> Data
}

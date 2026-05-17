import DomainModels
import Foundation
import TMDBClient

final class SearchListInteractor: SearchListInteractorProtocol {
    private let tmdbClient: any TMDBClientProtocol

    init(tmdbClient: any TMDBClientProtocol) {
        self.tmdbClient = tmdbClient
    }

    func searchMovies(query: String) async throws(TMDBError) -> [Movie] {
        try await tmdbClient.fetchSearch(query: query)
    }

    func fetchPosterData(posterPath: String) async throws(TMDBError) -> Data {
        try await tmdbClient.fetchPosterData(posterPath: posterPath, size: .thumbnail)
    }
}

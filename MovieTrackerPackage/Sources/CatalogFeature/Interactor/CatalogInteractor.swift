import DomainModels
import Foundation
import TMDBClient

final class CatalogInteractor: CatalogInteractorProtocol {
    private let tmdbClient: any TMDBClientProtocol

    init(tmdbClient: any TMDBClientProtocol) {
        self.tmdbClient = tmdbClient
    }

    func fetchTrending() async throws(TMDBError) -> [Movie] {
        try await tmdbClient.fetchTrending()
    }

    func fetchPosterData(posterPath: String) async throws(TMDBError) -> Data {
        try await tmdbClient.fetchPosterData(posterPath: posterPath, size: .thumbnail)
    }
}

import DomainModels
import TMDBClient

final class SearchFilterSheetInteractor: SearchFilterSheetInteractorProtocol {
    private let tmdbClient: any TMDBClientProtocol

    init(tmdbClient: any TMDBClientProtocol) {
        self.tmdbClient = tmdbClient
    }

    func fetchGenres(force: Bool) async throws(TMDBError) -> [Genre] {
        try await tmdbClient.fetchGenres(force: force)
    }
}

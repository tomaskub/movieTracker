import DomainModels
import Foundation
import TMDBClient

protocol CatalogInteractorProtocol: AnyObject {
    func fetchTrending() async throws(TMDBError) -> [Movie]
    func fetchPosterData(posterPath: String) async throws(TMDBError) -> Data
}

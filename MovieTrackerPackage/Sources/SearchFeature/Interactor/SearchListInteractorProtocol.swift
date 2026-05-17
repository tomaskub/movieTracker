import DomainModels
import Foundation
import TMDBClient

protocol SearchListInteractorProtocol: AnyObject {
    func searchMovies(query: String) async throws(TMDBError) -> [Movie]
    func fetchPosterData(posterPath: String) async throws(TMDBError) -> Data
}

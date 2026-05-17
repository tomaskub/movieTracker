import DomainModels
import TMDBClient

protocol SearchFilterSheetInteractorProtocol: AnyObject {
    func fetchGenres(force: Bool) async throws(TMDBError) -> [Genre]
}

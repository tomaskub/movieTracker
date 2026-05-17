import DomainModels
import TMDBClient

enum GenreLoadState {
    case loading
    case loaded([Genre])
    case error(TMDBError)
}

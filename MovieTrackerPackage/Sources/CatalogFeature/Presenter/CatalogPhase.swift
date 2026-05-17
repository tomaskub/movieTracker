import TMDBClient

enum CatalogPhase {
    case idle
    case loading
    case loaded([CatalogMovieRow])
    case failed(TMDBError)
}

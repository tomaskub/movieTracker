import DomainModels
import TMDBClient

enum SearchState {
    case idle
    case loading(query: String)
    case results(all: [Movie], filtered: [Movie])
    case empty(reason: EmptyReason)
    case error(TMDBError, query: String)
}

extension SearchState {
    enum EmptyReason {
        case noMatches
        case filtersEliminated
    }
}

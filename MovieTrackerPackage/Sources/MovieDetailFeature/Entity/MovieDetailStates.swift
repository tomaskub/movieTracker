import DomainModels
import TMDBClient

enum DetailState: Equatable {
    case loading
    case loaded(MovieDetail)
    case error(TMDBError)
}

enum MovieDetailCastState: Equatable {
    case loading
    case loaded([CastMember])
    case unavailable
}

enum WatchlistState: Equatable {
    case loading
    case onWatchlist
    case notOnWatchlist
    case mutating
    case error(String)
}

enum ReviewState: Equatable {
    case loading
    case hasReview(Review)
    case noReview
    case error(String)
}

enum WizardPresentation: Identifiable, Equatable {
    case create
    case edit

    var id: String {
        switch self {
        case .create: "create"
        case .edit: "edit"
        }
    }
}

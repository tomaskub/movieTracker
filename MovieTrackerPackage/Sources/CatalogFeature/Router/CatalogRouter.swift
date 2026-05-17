import MovieDetailFeature
import Observation
import SwiftUI
import TMDBClient
import WatchlistRepository
import ReviewRepository

protocol CatalogRouterProtocol: AnyObject {
    func navigate(to movieId: Int)
}

@Observable
@MainActor
public final class CatalogRouter: CatalogRouterProtocol {
    
    var navigationPath: NavigationPath = NavigationPath()

    private let tmdbClient: any TMDBClientProtocol
    private let presenter: CatalogPresenter
    let movieDetailRouter: MovieDetailRouter

    public init(
        tmdbClient: any TMDBClientProtocol,
        watchlistRepository: any WatchlistRepository,
        reviewRepository: any ReviewRepository
    ) {
        self.tmdbClient = tmdbClient
        self.movieDetailRouter = MovieDetailRouter(
            tmdbClient: tmdbClient,
            watchlistRepository: watchlistRepository,
            reviewRepository: reviewRepository
        )
        let interactor = CatalogInteractor(tmdbClient: tmdbClient)
        let presenter = CatalogPresenter(interactor: interactor)
        self.presenter = presenter
        presenter.router = self
    }

    func navigate(to movieId: Int) {
        navigationPath.append(movieId)
    }

    public func makeRootView() -> some View {
        CatalogView(presenter: presenter, router: self)
    }
}

import Observation
import SwiftUI
import TMDBClient

protocol CatalogRouterProtocol: AnyObject {
    func navigate(to movieId: Int)
}

@Observable
@MainActor
public final class CatalogRouter: CatalogRouterProtocol {
    
    var navigationPath: NavigationPath = NavigationPath()

    private let tmdbClient: any TMDBClientProtocol
    private let presenter: CatalogPresenter

    public init(tmdbClient: any TMDBClientProtocol) {
        self.tmdbClient = tmdbClient
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

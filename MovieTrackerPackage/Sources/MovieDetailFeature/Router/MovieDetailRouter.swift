import DomainModels
import Observation
import ReviewRepository
import SwiftUI
import TMDBClient
import WatchlistRepository

protocol MovieDetailRouterProtocol: AnyObject {
    func presentWizard(mode: WizardPresentation)
    func dismissWizard()
}

@Observable
@MainActor
public final class MovieDetailRouter: MovieDetailRouterProtocol {
    var wizardPresentation: WizardPresentation?

    private let tmdbClient: any TMDBClientProtocol
    private let watchlistRepository: any WatchlistRepository
    private let reviewRepository: any ReviewRepository

    public init(
        tmdbClient: any TMDBClientProtocol,
        watchlistRepository: any WatchlistRepository,
        reviewRepository: any ReviewRepository
    ) {
        self.tmdbClient = tmdbClient
        self.watchlistRepository = watchlistRepository
        self.reviewRepository = reviewRepository
    }

    func presentWizard(mode: WizardPresentation) {
        wizardPresentation = mode
    }

    func dismissWizard() {
        wizardPresentation = nil
    }

    public func makeView(movieId: Int) -> some View {
        let interactor = MovieDetailInteractor(
            tmdbClient: tmdbClient,
            watchlistRepository: watchlistRepository,
            reviewRepository: reviewRepository
        )
        let presenter = MovieDetailPresenter(movieId: movieId, interactor: interactor)
        presenter.router = self
        return MovieDetailView(presenter: presenter, router: self)
    }

    func makeWizardView(movieId: Int, mode: WizardPresentation) -> some View {
        Text("Review Wizard")
    }
}

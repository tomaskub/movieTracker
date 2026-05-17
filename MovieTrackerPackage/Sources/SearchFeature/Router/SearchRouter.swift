import MovieDetailFeature
import Observation
import ReviewRepository
import SwiftUI
import TMDBClient
import WatchlistRepository

@Observable
@MainActor
public final class SearchRouter: SearchRouterProtocol {
    var navigationPath: NavigationPath = NavigationPath()

    private let tmdbClient: any TMDBClientProtocol
    private let listInteractor: SearchListInteractor
    private let filterInteractor: SearchFilterSheetInteractor
    private let listPresenter: SearchListPresenter
    private let filterSheetPresenter: SearchFilterSheetPresenter
    private let sortSheetPresenter: SearchSortSheetPresenter
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
        self.listInteractor = SearchListInteractor(tmdbClient: tmdbClient)
        self.filterInteractor = SearchFilterSheetInteractor(tmdbClient: tmdbClient)
        self.listPresenter = SearchListPresenter(interactor: listInteractor)
        
        self.filterSheetPresenter = SearchFilterSheetPresenter(
            interactor: filterInteractor,
            onConfirm: { [weak listPresenter] filters in
                listPresenter?.commitFilters(filters)
            }
        )
        
        self.sortSheetPresenter = SearchSortSheetPresenter(
            onConfirm: { [weak listPresenter] sort in
                listPresenter?.commitSort(sort)
            }
        )
        
        listPresenter.onOpenFilterSheet = { [weak filterSheetPresenter] filters in
            filterSheetPresenter?.reset(from: filters)
        }
        listPresenter.onOpenSortSheet = { [weak sortSheetPresenter] sort in
            sortSheetPresenter?.reset(to: sort)
        }
        listPresenter.router = self
    }

    func pushMovieDetail(movieId: Int) {
        navigationPath.append(movieId)
    }

    public func makeRootView() -> some View {
        return SearchListView(
            presenter: listPresenter,
            filterSheetPresenter: filterSheetPresenter,
            sortSheetPresenter: sortSheetPresenter,
            router: self
        )
    }
}

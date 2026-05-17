#if DEBUG
import DomainModels
import MovieDetailFeature
import ReviewRepository
import SwiftUI
import TMDBClient
import WatchlistRepository

private final class PreviewWatchlistRepository: WatchlistRepository {
    func add(movie: Movie) throws {}
    func remove(movieId: Int) throws {}
    func fetchAll(sortOrder: WatchlistSortOrder?) throws -> [WatchlistEntry] { [] }
    func contains(movieId: Int) throws -> Bool { false }
}

private final class PreviewReviewRepository: ReviewRepository {
    func create(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws {}
    func update(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws {}
    func fetch(movieId: Int) throws -> Review? { nil }
    func delete(movieId: Int) throws {}
    func contains(movieId: Int) throws -> Bool { false }
}

private final class MockCatalogInteractor: CatalogInteractorProtocol {
    enum Behavior {
        case success([Movie])
        case failure(TMDBError)
        case loading
    }

    private let behavior: Behavior

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func fetchTrending() async throws(TMDBError) -> [Movie] {
        switch behavior {
        case .success(let movies):
            return movies
        case .failure(let error):
            throw error
        case .loading:
            try? await Task.sleep(for: .seconds(3600))
            return []
        }
    }

    func fetchPosterData(posterPath: String) async throws(TMDBError) -> Data {
        throw .networkFailure
    }
}

private final class PreviewTMDBClient: TMDBClientProtocol {
    func fetchTrending() async throws(TMDBError) -> [Movie] { [] }
    func fetchSearch(query: String) async throws(TMDBError) -> [Movie] { [] }
    func fetchMovie(id: Int) async throws(TMDBError) -> MovieDetail { throw .networkFailure }
    func fetchCredits(id: Int) async throws(TMDBError) -> [CastMember] { [] }
    func fetchGenres(force: Bool) async throws(TMDBError) -> [Genre] { [] }
    func fetchPosterData(movie: Movie, size: PosterSize) async throws(TMDBError) -> Data { throw .networkFailure }
    func fetchPosterData(posterPath: String, size: PosterSize) async throws(TMDBError) -> Data { throw .networkFailure }
}

@MainActor
private func makePreviewView(behavior: MockCatalogInteractor.Behavior) -> some View {
    let interactor = MockCatalogInteractor(behavior: behavior)
    let presenter = CatalogPresenter(interactor: interactor)
    let router = CatalogRouter(
        tmdbClient: PreviewTMDBClient(),
        watchlistRepository: PreviewWatchlistRepository(),
        reviewRepository: PreviewReviewRepository()
    )
    presenter.router = router
    return CatalogView(presenter: presenter, router: router)
}

#Preview("Loaded") {
    makePreviewView(behavior: .success(MovieFixtures.all))
}

#Preview("Failed") {
    makePreviewView(behavior: .failure(.networkFailure))
}

#Preview("Loading") {
    makePreviewView(behavior: .loading)
}

#Preview("Idle") {
    NavigationStack {
        Color.clear
            .navigationTitle("Trending")
            .navigationBarTitleDisplayMode(.large)
    }
}
#endif

import DomainModels
import TMDBClient
import XCTest
@testable import CatalogFeature

@MainActor
final class CatalogPresenterTests: XCTestCase {

    private final class MockCatalogInteractor: CatalogInteractorProtocol {
        var fetchTrendingResult: Result<[Movie], TMDBError> = .success([])
        var fetchCallCount = 0

        func fetchTrending() async throws(TMDBError) -> [Movie] {
            fetchCallCount += 1
            switch fetchTrendingResult {
            case .success(let movies): return movies
            case .failure(let error): throw error
            }
        }

        func fetchPosterData(posterPath: String) async throws(TMDBError) -> Data {
            throw .networkFailure
        }
    }

    private let fixtures: [Movie] = [
        Movie(id: 1, title: "Film A", overview: "", releaseDate: "2024-01-01", genreIds: [], posterPath: nil, voteAverage: 7.0),
        Movie(id: 2, title: "Film B", overview: "", releaseDate: "2023-06-15", genreIds: [], posterPath: nil, voteAverage: 8.0),
    ]

    private func flushTasks() async {
        for _ in 0..<10 { await Task.yield() }
    }

    func testNonEmptyFetchSuccessTransitionToLoaded() async {
        let interactor = MockCatalogInteractor()
        interactor.fetchTrendingResult = .success(fixtures)
        let presenter = CatalogPresenter(interactor: interactor)

        presenter.handleAppear()
        guard case .loading = presenter.phase else {
            XCTFail("Expected .loading immediately after handleAppear()")
            return
        }

        await flushTasks()

        guard case .loaded(let rows) = presenter.phase else {
            XCTFail("Expected .loaded; got \(presenter.phase)")
            return
        }
        XCTAssertEqual(rows.count, fixtures.count)
    }

    func testEmptyFetchResultTransitionToFailed() async {
        let interactor = MockCatalogInteractor()
        interactor.fetchTrendingResult = .success([])
        let presenter = CatalogPresenter(interactor: interactor)

        presenter.handleAppear()
        await flushTasks()

        guard case .failed(let error) = presenter.phase else {
            XCTFail("Expected .failed; got \(presenter.phase)")
            return
        }
        XCTAssertEqual(error, .networkFailure)
    }

    func testFetchThrowsTransitionToFailed() async {
        let interactor = MockCatalogInteractor()
        interactor.fetchTrendingResult = .failure(.offline)
        let presenter = CatalogPresenter(interactor: interactor)

        presenter.handleAppear()
        await flushTasks()

        guard case .failed(let error) = presenter.phase else {
            XCTFail("Expected .failed; got \(presenter.phase)")
            return
        }
        XCTAssertEqual(error, .offline)
    }

    func testRetryFromFailedTransitionsToLoading() async {
        let interactor = MockCatalogInteractor()
        interactor.fetchTrendingResult = .failure(.networkFailure)
        let presenter = CatalogPresenter(interactor: interactor)

        presenter.handleAppear()
        await flushTasks()

        guard case .failed = presenter.phase else {
            XCTFail("Expected .failed before retry")
            return
        }

        presenter.handleRetry()

        guard case .loading = presenter.phase else {
            XCTFail("Expected .loading after handleRetry()")
            return
        }
    }

    func testHandleAppearWhenLoadedDoesNotDispatchSecondFetch() async {
        let interactor = MockCatalogInteractor()
        interactor.fetchTrendingResult = .success(fixtures)
        let presenter = CatalogPresenter(interactor: interactor)

        presenter.handleAppear()
        await flushTasks()

        guard case .loaded = presenter.phase else {
            XCTFail("Expected .loaded")
            return
        }

        presenter.handleAppear()
        await flushTasks()

        XCTAssertEqual(interactor.fetchCallCount, 1)
    }

    func testHandleAppearWhenLoadingDoesNotDispatchSecondFetch() async {
        let interactor = MockCatalogInteractor()
        interactor.fetchTrendingResult = .success(fixtures)
        let presenter = CatalogPresenter(interactor: interactor)

        presenter.handleAppear()
        guard case .loading = presenter.phase else {
            XCTFail("Expected .loading")
            return
        }

        presenter.handleAppear()
        await flushTasks()

        XCTAssertEqual(interactor.fetchCallCount, 1)
    }
}

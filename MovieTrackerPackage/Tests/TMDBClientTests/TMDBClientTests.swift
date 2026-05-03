import XCTest
import TMDBClient
import DomainModels
import Networking

final class TMDBClientTests: XCTestCase {
    private var mock: MockHTTPClient!
    private var sut: TMDBClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        sut = TMDBClient(httpClient: mock)
    }

    override func tearDown() {
        sut = nil
        mock = nil
        super.tearDown()
    }

    // MARK: - Error mapping

    func test_networkError_noConnectivity_mapsToOffline() async {
        mock.fetchResponses = [.failure(.noConnectivity)]
        await assertThrowsTMDBError(try await sut.fetchTrending()) {
            XCTAssertEqual($0, .offline)
        }
    }

    func test_networkError_serverError_mapsToNetworkFailure() async {
        mock.fetchResponses = [.failure(.serverError(statusCode: 500))]
        await assertThrowsTMDBError(try await sut.fetchTrending()) {
            XCTAssertEqual($0, .networkFailure)
        }
    }

    func test_networkError_transportError_mapsToNetworkFailure() async {
        mock.fetchResponses = [.failure(.transportError(URLError(.timedOut)))]
        await assertThrowsTMDBError(try await sut.fetchTrending()) {
            XCTAssertEqual($0, .networkFailure)
        }
    }

    func test_networkError_decodingError_mapsToNetworkFailure() async {
        let decodingError = DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "bad data")
        )
        mock.fetchResponses = [.failure(.decodingError(decodingError))]
        await assertThrowsTMDBError(try await sut.fetchTrending()) {
            XCTAssertEqual($0, .networkFailure)
        }
    }

    // MARK: - fetchTrending

    func test_fetchTrending_usesCorrectPath() async throws {
        mock.fetchResponses = [.success(Fixtures.pagedMoviesJSON)]
        _ = try await sut.fetchTrending()
        XCTAssertEqual(mock.capturedRequests.last?.path, "/trending/movie/week")
    }

    func test_fetchTrending_returnsDecodedMovies() async throws {
        mock.fetchResponses = [.success(Fixtures.pagedMoviesJSON)]
        let movies = try await sut.fetchTrending()
        XCTAssertEqual(movies.count, 1)
        XCTAssertEqual(movies[0].id, 1)
        XCTAssertEqual(movies[0].title, "The Batman")
        XCTAssertEqual(movies[0].voteAverage, 7.8)
    }

    // MARK: - fetchSearch

    func test_fetchSearch_usesCorrectPath() async throws {
        mock.fetchResponses = [.success(Fixtures.pagedMoviesJSON)]
        _ = try await sut.fetchSearch(query: "Batman")
        XCTAssertEqual(mock.capturedRequests.last?.path, "/search/movie")
    }

    func test_fetchSearch_includesQueryItemInRequest() async throws {
        mock.fetchResponses = [.success(Fixtures.pagedMoviesJSON)]
        _ = try await sut.fetchSearch(query: "Batman")
        let items = mock.capturedRequests.last?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "query", value: "Batman")))
    }

    func test_fetchSearch_returnsDecodedMovies() async throws {
        mock.fetchResponses = [.success(Fixtures.pagedMoviesJSON)]
        let movies = try await sut.fetchSearch(query: "Batman")
        XCTAssertEqual(movies.count, 1)
        XCTAssertEqual(movies[0].id, 1)
    }

    // MARK: - fetchMovie

    func test_fetchMovie_usesCorrectPath() async throws {
        mock.fetchResponses = [.success(Fixtures.movieDetailJSON)]
        _ = try await sut.fetchMovie(id: 42)
        XCTAssertEqual(mock.capturedRequests.last?.path, "/movie/42")
    }

    func test_fetchMovie_returnsCastAsNotRetrieved() async throws {
        mock.fetchResponses = [.success(Fixtures.movieDetailJSON)]
        let detail = try await sut.fetchMovie(id: 1)
        XCTAssertEqual(detail.cast, .notRetrieved)
    }

    func test_fetchMovie_populatesGenresOnDetail() async throws {
        mock.fetchResponses = [.success(Fixtures.movieDetailJSON)]
        let detail = try await sut.fetchMovie(id: 1)
        XCTAssertEqual(detail.genres.count, 1)
        XCTAssertEqual(detail.genres[0].id, 28)
        XCTAssertEqual(detail.genres[0].name, "Action")
    }

    func test_fetchMovie_mapsGenreIdsFromGenreObjects() async throws {
        mock.fetchResponses = [.success(Fixtures.movieDetailJSON)]
        let detail = try await sut.fetchMovie(id: 1)
        XCTAssertEqual(detail.movie.genreIds, [28])
    }

    func test_fetchMovie_mapsCoreFields() async throws {
        mock.fetchResponses = [.success(Fixtures.movieDetailJSON)]
        let detail = try await sut.fetchMovie(id: 1)
        XCTAssertEqual(detail.movie.id, 1)
        XCTAssertEqual(detail.movie.title, "The Batman")
        XCTAssertEqual(detail.movie.overview, "DC hero")
        XCTAssertEqual(detail.movie.posterPath, "/batman.jpg")
        XCTAssertEqual(detail.movie.voteAverage, 7.8)
    }

    // MARK: - fetchCredits

    func test_fetchCredits_usesCorrectPath() async throws {
        mock.fetchResponses = [.success(Fixtures.creditsJSON)]
        _ = try await sut.fetchCredits(id: 42)
        XCTAssertEqual(mock.capturedRequests.last?.path, "/movie/42/credits")
    }

    func test_fetchCredits_returnsDecodedCastArray() async throws {
        mock.fetchResponses = [.success(Fixtures.creditsJSON)]
        let cast = try await sut.fetchCredits(id: 1)
        XCTAssertEqual(cast.count, 1)
        XCTAssertEqual(cast[0].name, "Robert Pattinson")
        XCTAssertEqual(cast[0].character, "Batman")
    }

    // MARK: - fetchGenres

    func test_fetchGenres_usesCorrectPath() async throws {
        mock.fetchResponses = [.success(Fixtures.genreListJSON)]
        _ = try await sut.fetchGenres(force: false)
        XCTAssertEqual(mock.capturedRequests.last?.path, "/genre/movie/list")
    }

    func test_fetchGenres_returnsDecodedGenres() async throws {
        mock.fetchResponses = [.success(Fixtures.genreListJSON)]
        let genres = try await sut.fetchGenres(force: false)
        XCTAssertEqual(genres.count, 2)
        XCTAssertEqual(genres[0].id, 28)
        XCTAssertEqual(genres[0].name, "Action")
    }

    func test_fetchGenres_secondCall_returnsCachedValue_withoutNewRequest() async throws {
        mock.fetchResponses = [.success(Fixtures.genreListJSON)]
        let first = try await sut.fetchGenres(force: false)
        let second = try await sut.fetchGenres(force: false)
        XCTAssertEqual(mock.capturedRequests.count, 1)
        XCTAssertEqual(first, second)
    }

    func test_fetchGenres_forceTrue_bypassesCache_andDispatchesNewRequest() async throws {
        mock.fetchResponses = [
            .success(Fixtures.genreListJSON),
            .success(Fixtures.updatedGenreListJSON)
        ]
        _ = try await sut.fetchGenres(force: false)
        let refreshed = try await sut.fetchGenres(force: true)
        XCTAssertEqual(mock.capturedRequests.count, 2)
        XCTAssertEqual(refreshed.count, 1)
        XCTAssertEqual(refreshed[0].name, "Horror")
    }

    func test_fetchGenres_forceTrue_updatesCache_forSubsequentRequests() async throws {
        mock.fetchResponses = [
            .success(Fixtures.genreListJSON),
            .success(Fixtures.updatedGenreListJSON)
        ]
        _ = try await sut.fetchGenres(force: false)
        _ = try await sut.fetchGenres(force: true)
        let cached = try await sut.fetchGenres(force: false)
        XCTAssertEqual(mock.capturedRequests.count, 2)
        XCTAssertEqual(cached[0].name, "Horror")
    }

    func test_fetchGenres_emptyResponse_doesNotOverwriteExistingCache() async throws {
        mock.fetchResponses = [
            .success(Fixtures.genreListJSON),
            .success(Fixtures.emptyGenreListJSON)
        ]
        _ = try await sut.fetchGenres(force: false)
        _ = try await sut.fetchGenres(force: true)
        let cached = try await sut.fetchGenres(force: false)
        XCTAssertEqual(mock.capturedRequests.count, 2)
        XCTAssertEqual(cached.count, 2)
        XCTAssertEqual(cached[0].name, "Action")
    }

    func test_fetchGenres_failedFetch_doesNotOverwriteExistingCache() async throws {
        mock.fetchResponses = [
            .success(Fixtures.genreListJSON),
            .failure(.noConnectivity)
        ]
        _ = try await sut.fetchGenres(force: false)
        _ = try? await sut.fetchGenres(force: true)
        let cached = try await sut.fetchGenres(force: false)
        XCTAssertEqual(mock.capturedRequests.count, 2)
        XCTAssertEqual(cached.count, 2)
        XCTAssertEqual(cached[0].name, "Action")
    }

    // MARK: - fetchPosterData(movie:size:)

    func test_fetchPosterData_movie_thumbnail_constructsW185URL() async throws {
        let movie = makeMovie(posterPath: "/batman.jpg")
        mock.fetchDataResponses = [.success(Data("img".utf8))]
        _ = try await sut.fetchPosterData(movie: movie, size: .thumbnail)
        let url = try XCTUnwrap(mock.capturedImageURLs.last)
        XCTAssertEqual(url.absoluteString, "https://image.tmdb.org/t/p/w185/batman.jpg")
    }

    func test_fetchPosterData_movie_full_constructsW500URL() async throws {
        let movie = makeMovie(posterPath: "/batman.jpg")
        mock.fetchDataResponses = [.success(Data("img".utf8))]
        _ = try await sut.fetchPosterData(movie: movie, size: .full)
        let url = try XCTUnwrap(mock.capturedImageURLs.last)
        XCTAssertEqual(url.absoluteString, "https://image.tmdb.org/t/p/w500/batman.jpg")
    }

    func test_fetchPosterData_movie_nilPosterPath_throwsNetworkFailure() async {
        let movie = makeMovie(posterPath: nil)
        await assertThrowsTMDBError(try await sut.fetchPosterData(movie: movie, size: .thumbnail)) {
            XCTAssertEqual($0, .networkFailure)
        }
    }

    func test_fetchPosterData_movie_returnsImageData() async throws {
        let expected = Data("poster-bytes".utf8)
        let movie = makeMovie(posterPath: "/batman.jpg")
        mock.fetchDataResponses = [.success(expected)]
        let result = try await sut.fetchPosterData(movie: movie, size: .full)
        XCTAssertEqual(result, expected)
    }

    // MARK: - fetchPosterData(posterPath:size:)

    func test_fetchPosterData_posterPath_constructsCorrectURL() async throws {
        mock.fetchDataResponses = [.success(Data())]
        _ = try await sut.fetchPosterData(posterPath: "/test.jpg", size: .thumbnail)
        let url = try XCTUnwrap(mock.capturedImageURLs.last)
        XCTAssertEqual(url.absoluteString, "https://image.tmdb.org/t/p/w185/test.jpg")
    }

    func test_fetchPosterData_posterPath_returnsImageData() async throws {
        let expected = Data("raw-image".utf8)
        mock.fetchDataResponses = [.success(expected)]
        let result = try await sut.fetchPosterData(posterPath: "/poster.jpg", size: .full)
        XCTAssertEqual(result, expected)
    }

    func test_fetchPosterData_posterPath_noConnectivity_mapsToOffline() async {
        mock.fetchDataResponses = [.failure(.noConnectivity)]
        await assertThrowsTMDBError(
            try await sut.fetchPosterData(posterPath: "/p.jpg", size: .full)
        ) {
            XCTAssertEqual($0, .offline)
        }
    }

    func test_fetchPosterData_posterPath_serverError_mapsToNetworkFailure() async {
        mock.fetchDataResponses = [.failure(.serverError(statusCode: 404))]
        await assertThrowsTMDBError(
            try await sut.fetchPosterData(posterPath: "/p.jpg", size: .full)
        ) {
            XCTAssertEqual($0, .networkFailure)
        }
    }
}

// MARK: - Helpers

extension TMDBClientTests {
    private func assertThrowsTMDBError<T>(
        _ expression: @autoclosure () async throws(TMDBError) -> T,
        file: StaticString = #filePath,
        line: UInt = #line,
        verify: (TMDBError) -> Void
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected TMDBError to be thrown", file: file, line: line)
        } catch {
            verify(error)
        }
    }

    private func makeMovie(posterPath: String?) -> Movie {
        Movie(
            id: 1,
            title: "The Batman",
            overview: "DC hero",
            releaseDate: "2022-03-04",
            genreIds: [28],
            posterPath: posterPath,
            voteAverage: 7.8
        )
    }
}

// MARK: - Fixtures

private enum Fixtures {
    static let pagedMoviesJSON = Data("""
    {
        "results": [{
            "id": 1,
            "title": "The Batman",
            "overview": "DC hero",
            "release_date": "2022-03-04",
            "genre_ids": [28],
            "poster_path": "/batman.jpg",
            "vote_average": 7.8
        }]
    }
    """.utf8)

    static let movieDetailJSON = Data("""
    {
        "id": 1,
        "title": "The Batman",
        "overview": "DC hero",
        "release_date": "2022-03-04",
        "genres": [{"id": 28, "name": "Action"}],
        "poster_path": "/batman.jpg",
        "vote_average": 7.8
    }
    """.utf8)

    static let creditsJSON = Data("""
    {
        "cast": [{"name": "Robert Pattinson", "character": "Batman"}]
    }
    """.utf8)

    static let genreListJSON = Data("""
    {
        "genres": [
            {"id": 28, "name": "Action"},
            {"id": 18, "name": "Drama"}
        ]
    }
    """.utf8)

    static let updatedGenreListJSON = Data("""
    {
        "genres": [{"id": 27, "name": "Horror"}]
    }
    """.utf8)

    static let emptyGenreListJSON = Data("""
    {
        "genres": []
    }
    """.utf8)
}

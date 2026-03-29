import XCTest
import Networking
@testable import TMDBClient

final class LiveTMDBClientTests: XCTestCase {

    private var mock: MockHTTPClient!
    private var sut: LiveTMDBClient!

    override func setUp() {
        super.setUp()
        mock = MockHTTPClient()
        sut = LiveTMDBClient(httpClient: mock)
    }

    // MARK: - fetchTrendingMovies

    func test_fetchTrendingMovies_returnsMovies_onSuccess() async throws {
        mock.stubbedJSONData = """
        {
            "results": [
                {"id": 1, "title": "Movie A", "overview": "Overview A", "release_date": "2024-01-01", "genre_ids": [28], "poster_path": "/a.jpg", "vote_average": 7.5},
                {"id": 2, "title": "Movie B", "overview": null, "release_date": null, "genre_ids": [], "poster_path": null, "vote_average": 6.0}
            ]
        }
        """.data(using: .utf8)

        let movies = try await sut.fetchTrendingMovies()

        XCTAssertEqual(movies.count, 2)
        XCTAssertEqual(movies[0].id, 1)
        XCTAssertEqual(movies[0].title, "Movie A")
        XCTAssertEqual(movies[0].releaseDate, "2024-01-01")
        XCTAssertEqual(movies[0].genreIds, [28])
        XCTAssertEqual(movies[0].posterPath, "/a.jpg")
        XCTAssertEqual(movies[0].voteAverage, 7.5)
        XCTAssertNil(movies[1].overview)
        XCTAssertNil(movies[1].releaseDate)
        XCTAssertNil(movies[1].posterPath)
    }

    func test_fetchTrendingMovies_usesCorrectEndpoint() async throws {
        mock.stubbedJSONData = #"{"results": []}"#.data(using: .utf8)

        _ = try await sut.fetchTrendingMovies()

        XCTAssertEqual(mock.lastExecutedPath, "/trending/movie/week")
    }

    func test_fetchTrendingMovies_throwsNetworkUnavailable_onNetworkError() async {
        mock.stubbedError = NetworkError.networkUnavailable

        do {
            _ = try await sut.fetchTrendingMovies()
            XCTFail("Expected ClientError.networkUnavailable")
        } catch ClientError.networkUnavailable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_fetchTrendingMovies_throwsServerError_onServerError() async {
        mock.stubbedError = NetworkError.serverError

        do {
            _ = try await sut.fetchTrendingMovies()
            XCTFail("Expected ClientError.serverError")
        } catch ClientError.serverError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - searchMovies

    func test_searchMovies_returnsMovies_onSuccess() async throws {
        mock.stubbedJSONData = """
        {
            "results": [
                {"id": 10, "title": "Inception", "overview": "A dream.", "release_date": "2010-07-16", "genre_ids": [878, 28], "poster_path": "/inc.jpg", "vote_average": 8.8}
            ]
        }
        """.data(using: .utf8)

        let movies = try await sut.searchMovies(query: "Inception")

        XCTAssertEqual(movies.count, 1)
        XCTAssertEqual(movies[0].id, 10)
        XCTAssertEqual(movies[0].title, "Inception")
    }

    func test_searchMovies_passesQueryInRequest() async throws {
        mock.stubbedJSONData = #"{"results": []}"#.data(using: .utf8)

        _ = try await sut.searchMovies(query: "Dune")

        XCTAssertEqual(mock.lastExecutedPath, "/search/movie")
        XCTAssertTrue(mock.lastExecutedQueryItems.contains(URLQueryItem(name: "query", value: "Dune")))
    }

    func test_searchMovies_throwsServerError_onFailure() async {
        mock.stubbedError = NetworkError.serverError

        do {
            _ = try await sut.searchMovies(query: "any")
            XCTFail("Expected ClientError.serverError")
        } catch ClientError.serverError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - fetchMovieDetail

    func test_fetchMovieDetail_returnsMovieDetail_onSuccess() async throws {
        mock.stubbedJSONData = """
        {
            "id": 42,
            "title": "Interstellar",
            "overview": "Space travel.",
            "release_date": "2014-11-07",
            "genres": [{"id": 878, "name": "Science Fiction"}, {"id": 18, "name": "Drama"}],
            "poster_path": "/inter.jpg",
            "vote_average": 8.6,
            "runtime": 169
        }
        """.data(using: .utf8)

        let detail = try await sut.fetchMovieDetail(id: 42)

        XCTAssertEqual(detail.id, 42)
        XCTAssertEqual(detail.title, "Interstellar")
        XCTAssertEqual(detail.overview, "Space travel.")
        XCTAssertEqual(detail.releaseDate, "2014-11-07")
        XCTAssertEqual(detail.genres.count, 2)
        XCTAssertEqual(detail.genres[0], Genre(id: 878, name: "Science Fiction"))
        XCTAssertEqual(detail.posterPath, "/inter.jpg")
        XCTAssertEqual(detail.voteAverage, 8.6)
        XCTAssertEqual(detail.runtime, 169)
    }

    func test_fetchMovieDetail_usesCorrectEndpoint() async throws {
        mock.stubbedJSONData = """
        {"id": 99, "title": "T", "overview": null, "release_date": null, "genres": [], "poster_path": null, "vote_average": 0.0, "runtime": null}
        """.data(using: .utf8)

        _ = try await sut.fetchMovieDetail(id: 99)

        XCTAssertEqual(mock.lastExecutedPath, "/movie/99")
    }

    func test_fetchMovieDetail_throwsServerError_onFailure() async {
        mock.stubbedError = NetworkError.serverError

        do {
            _ = try await sut.fetchMovieDetail(id: 1)
            XCTFail("Expected ClientError.serverError")
        } catch ClientError.serverError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - fetchMovieCredits

    func test_fetchMovieCredits_returnsCastSortedByOrder() async throws {
        mock.stubbedJSONData = """
        {
            "cast": [
                {"id": 3, "name": "Actor C", "character": "Role C", "profile_path": null, "order": 2},
                {"id": 1, "name": "Actor A", "character": "Role A", "profile_path": "/a.jpg", "order": 0},
                {"id": 2, "name": "Actor B", "character": "Role B", "profile_path": "/b.jpg", "order": 1}
            ]
        }
        """.data(using: .utf8)

        let cast = try await sut.fetchMovieCredits(id: 5)

        XCTAssertEqual(cast.count, 3)
        XCTAssertEqual(cast[0].name, "Actor A")
        XCTAssertEqual(cast[1].name, "Actor B")
        XCTAssertEqual(cast[2].name, "Actor C")
    }

    func test_fetchMovieCredits_usesCorrectEndpoint() async throws {
        mock.stubbedJSONData = #"{"cast": []}"#.data(using: .utf8)

        _ = try await sut.fetchMovieCredits(id: 7)

        XCTAssertEqual(mock.lastExecutedPath, "/movie/7/credits")
    }

    func test_fetchMovieCredits_throwsNetworkUnavailable_onNetworkError() async {
        mock.stubbedError = NetworkError.networkUnavailable

        do {
            _ = try await sut.fetchMovieCredits(id: 1)
            XCTFail("Expected ClientError.networkUnavailable")
        } catch ClientError.networkUnavailable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - fetchGenres

    func test_fetchGenres_returnsGenres_onSuccess() async throws {
        mock.stubbedJSONData = """
        {
            "genres": [
                {"id": 28, "name": "Action"},
                {"id": 12, "name": "Adventure"},
                {"id": 16, "name": "Animation"}
            ]
        }
        """.data(using: .utf8)

        let genres = try await sut.fetchGenres()

        XCTAssertEqual(genres.count, 3)
        XCTAssertEqual(genres[0], Genre(id: 28, name: "Action"))
        XCTAssertEqual(genres[1], Genre(id: 12, name: "Adventure"))
        XCTAssertEqual(genres[2], Genre(id: 16, name: "Animation"))
    }

    func test_fetchGenres_usesCorrectEndpoint() async throws {
        mock.stubbedJSONData = #"{"genres": []}"#.data(using: .utf8)

        _ = try await sut.fetchGenres()

        XCTAssertEqual(mock.lastExecutedPath, "/genre/movie/list")
    }

    func test_fetchGenres_throwsServerError_onFailure() async {
        mock.stubbedError = NetworkError.serverError

        do {
            _ = try await sut.fetchGenres()
            XCTFail("Expected ClientError.serverError")
        } catch ClientError.serverError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - fetchImage

    func test_fetchImage_thumbnail_usesThumbnailSizeVariant() async throws {
        mock.fetchImageResult = .success(Data([0x01]))

        _ = try await sut.fetchImage(path: "/poster.jpg", size: .thumbnail)

        XCTAssertEqual(mock.lastImageRequest?.sizeVariant, "w185")
    }

    func test_fetchImage_medium_usesMediumSizeVariant() async throws {
        mock.fetchImageResult = .success(Data([0x02]))

        _ = try await sut.fetchImage(path: "/poster.jpg", size: .medium)

        XCTAssertEqual(mock.lastImageRequest?.sizeVariant, "w500")
    }

    func test_fetchImage_original_usesOriginalSizeVariant() async throws {
        mock.fetchImageResult = .success(Data([0x03]))

        _ = try await sut.fetchImage(path: "/poster.jpg", size: .original)

        XCTAssertEqual(mock.lastImageRequest?.sizeVariant, "original")
    }

    func test_fetchImage_returnsData_onSuccess() async throws {
        let expectedData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        mock.fetchImageResult = .success(expectedData)

        let result = try await sut.fetchImage(path: "/poster.jpg", size: .medium)

        XCTAssertEqual(result, expectedData)
    }

    func test_fetchImage_throwsNetworkUnavailable_onNetworkError() async {
        mock.fetchImageResult = .failure(NetworkError.networkUnavailable)

        do {
            _ = try await sut.fetchImage(path: "/poster.jpg", size: .medium)
            XCTFail("Expected ClientError.networkUnavailable")
        } catch ClientError.networkUnavailable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_fetchImage_throwsServerError_onServerError() async {
        mock.fetchImageResult = .failure(NetworkError.serverError)

        do {
            _ = try await sut.fetchImage(path: "/poster.jpg", size: .medium)
            XCTFail("Expected ClientError.serverError")
        } catch ClientError.serverError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

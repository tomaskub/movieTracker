import DomainModels
import Foundation
import Networking

public actor TMDBClient: TMDBClientProtocol {

    private let httpClient: any HTTPClient
    private var genreCache: [Genre]?

    private static let imageBaseURL = "https://image.tmdb.org/t/p/"

    public init(httpClient: any HTTPClient) {
        self.httpClient = httpClient
    }

    public func fetchTrending() async throws(TMDBError) -> [Movie] {
        let response: PagedResults<Movie> = try await perform(
            HTTPRequest(path: "/trending/movie/week")
        )
        return response.results
    }

    public func fetchSearch(query: String) async throws(TMDBError) -> [Movie] {
        let request = HTTPRequest(
            path: "/search/movie",
            queryItems: [URLQueryItem(name: "query", value: query)]
        )
        let response: PagedResults<Movie> = try await perform(request)
        return response.results
    }

    public func fetchMovie(id: Int) async throws(TMDBError) -> MovieDetail {
        let response: MovieDetailResponse = try await perform(
            HTTPRequest(path: "/movie/\(id)")
        )
        return response.toDomain()
    }

    public func fetchCredits(id: Int) async throws(TMDBError) -> [CastMember] {
        let response: CreditsResponse = try await perform(
            HTTPRequest(path: "/movie/\(id)/credits")
        )
        return response.cast
    }

    public func fetchGenres(force: Bool) async throws(TMDBError) -> [Genre] {
        if !force, let cached = genreCache {
            return cached
        }
        let response: GenreListResponse = try await perform(
            HTTPRequest(path: "/genre/movie/list")
        )
        if !response.genres.isEmpty {
            genreCache = response.genres
        }
        return response.genres
    }

    public func fetchPosterData(movie: Movie, size: PosterSize) async throws(TMDBError) -> Data {
        guard let path = movie.posterPath else {
            throw TMDBError.networkFailure
        }
        return try await fetchPosterData(posterPath: path, size: size)
    }

    public func fetchPosterData(posterPath: String, size: PosterSize) async throws(TMDBError) -> Data {
        let urlString = Self.imageBaseURL + size.pathSegment + posterPath
        guard let url = URL(string: urlString) else {
            assertionFailure("Invalid image URL constructed from posterPath: \(posterPath)")
            throw TMDBError.invalidRequest
        }
        do {
            return try await httpClient.fetchData(from: url)
        } catch {
            throw TMDBError(from: error)
        }
    }

    private func perform<T: Decodable>(_ request: HTTPRequest) async throws(TMDBError) -> T {
        do {
            return try await httpClient.fetch(request)
        } catch {
            throw TMDBError(from: error)
        }
    }
}

private extension TMDBError {
    init(from networkError: NetworkError) {
        switch networkError {
        case .noConnectivity:
            self = .offline
        case .invalidURL:
            assertionFailure("Invalid HTTPRequest URL constructed inside TMDBClient")
            self = .invalidRequest
        case .serverError, .transportError, .decodingError:
            self = .networkFailure
        }
    }
}

private struct PagedResults<T: Decodable>: Decodable {
    let results: [T]
}

private struct GenreListResponse: Decodable {
    let genres: [Genre]
}

private struct CreditsResponse: Decodable {
    let cast: [CastMember]
}

private struct MovieDetailResponse: Decodable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: String
    let genres: [Genre]
    let posterPath: String?
    let voteAverage: Double

    enum CodingKeys: String, CodingKey {
        case id, title, overview, genres
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
    }

    func toDomain() -> MovieDetail {
        let movie = Movie(
            id: id,
            title: title,
            overview: overview,
            releaseDate: releaseDate,
            genreIds: genres.map(\.id),
            posterPath: posterPath,
            voteAverage: voteAverage
        )
        return MovieDetail(movie: movie, genres: genres, cast: .notRetrieved)
    }
}

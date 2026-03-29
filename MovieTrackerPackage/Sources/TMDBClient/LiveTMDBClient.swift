import Foundation
import Networking

public final class LiveTMDBClient: TMDBClient {
    private let httpClient: any HTTPClient

    public init(httpClient: any HTTPClient) {
        self.httpClient = httpClient
    }

    public func fetchTrendingMovies() async throws(ClientError) -> [Movie] {
        let request = Request<PagedResponse<Movie>>(path: "/trending/movie/week")
        do {
            let response = try await httpClient.execute(request)
            return response.results
        } catch {
            throw mapError(error)
        }
    }

    public func searchMovies(query: String) async throws(ClientError) -> [Movie] {
        let request = Request<PagedResponse<Movie>>(
            path: "/search/movie",
            queryItems: [URLQueryItem(name: "query", value: query)]
        )
        do {
            let response = try await httpClient.execute(request)
            return response.results
        } catch {
            throw mapError(error)
        }
    }

    public func fetchMovieDetail(id: Int) async throws(ClientError) -> MovieDetail {
        let request = Request<MovieDetail>(path: "/movie/\(id)")
        do {
            return try await httpClient.execute(request)
        } catch {
            throw mapError(error)
        }
    }

    public func fetchMovieCredits(id: Int) async throws(ClientError) -> [CastMember] {
        let request = Request<CreditsResponse>(path: "/movie/\(id)/credits")
        do {
            let response = try await httpClient.execute(request)
            return response.cast
                .sorted { $0.order < $1.order }
                .map { CastMember(id: $0.id, name: $0.name, character: $0.character, profilePath: $0.profilePath) }
        } catch {
            throw mapError(error)
        }
    }

    public func fetchGenres() async throws(ClientError) -> [Genre] {
        let request = Request<GenresResponse>(path: "/genre/movie/list")
        do {
            let response = try await httpClient.execute(request)
            return response.genres
        } catch {
            throw mapError(error)
        }
    }

    public func fetchImage(path: String, size: ImageSize) async throws(ClientError) -> Data {
        let imageRequest = ImageRequest(path: path, sizeVariant: size.sizeVariant)
        do {
            return try await httpClient.fetchImage(imageRequest)
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> ClientError {
        switch error as? NetworkError {
        case .networkUnavailable: return .networkUnavailable
        default: return .serverError
        }
    }
}

private struct PagedResponse<T: Decodable>: Decodable {
    let results: [T]
}

private struct CreditsResponse: Decodable {
    let cast: [CastMemberRaw]
}

private struct GenresResponse: Decodable {
    let genres: [Genre]
}

private struct CastMemberRaw: Decodable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int
}

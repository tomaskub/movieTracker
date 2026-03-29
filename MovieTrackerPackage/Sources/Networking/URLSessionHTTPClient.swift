import Foundation

public final class URLSessionHTTPClient: HTTPClient {
    private let baseURL: URL
    private let imageBaseURL: URL
    private let apiKey: String
    private let session: URLSession

    public init(baseURL: URL, imageBaseURL: URL, apiKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.imageBaseURL = imageBaseURL
        self.apiKey = apiKey
        self.session = session
    }

    public func execute<Response: Decodable>(_ request: Request<Response>) async throws -> Response {
        let url = try buildURL(base: baseURL, path: request.path, queryItems: request.queryItems + [URLQueryItem(name: "api_key", value: apiKey)])
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        let (data, response) = try await performRequest(urlRequest)
        try validateStatusCode(response)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw NetworkError.serverError
        }
    }

    public func fetchImage(_ request: ImageRequest) async throws -> Data {
        var components = URLComponents(url: imageBaseURL, resolvingAgainstBaseURL: false)
        let existingPath = imageBaseURL.path.hasSuffix("/") ? imageBaseURL.path : imageBaseURL.path + "/"
        let imagePath = request.path.hasPrefix("/") ? request.path : "/" + request.path
        components?.path = existingPath + request.sizeVariant + imagePath

        guard let url = components?.url else {
            throw NetworkError.serverError
        }

        let (data, response) = try await performRequest(URLRequest(url: url))
        try validateStatusCode(response)

        guard !data.isEmpty else {
            throw NetworkError.serverError
        }

        return data
    }

    private func buildURL(base: URL, path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw NetworkError.serverError
        }
        components.queryItems = (components.queryItems ?? []) + queryItems
        guard let url = components.url else {
            throw NetworkError.serverError
        }
        return url
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw mapError(error)
        }
    }

    private func validateStatusCode(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NetworkError.serverError
        }
    }

    private func mapError(_ error: Error) -> NetworkError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            default:
                return .serverError
            }
        }
        return .serverError
    }
}

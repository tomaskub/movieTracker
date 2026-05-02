import Foundation

public final class URLSessionHTTPClient: HTTPClient {
    private let configuration: NetworkConfiguration
    private let session: URLSession

    public init(configuration: NetworkConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func fetch<T: Decodable>(_ request: HTTPRequest) async throws(NetworkError) -> T {
        let url = try buildURL(for: request)
        let urlRequest = buildURLRequest(url: url, request: request)
        let data = try await execute(urlRequest)
        return try decode(data)
    }

    public func fetchData(from url: URL) async throws(NetworkError) -> Data {
        let urlRequest = URLRequest(url: url)
        return try await execute(urlRequest)
    }

    private func buildURL(for request: HTTPRequest) throws(NetworkError) -> URL {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw .invalidURL
        }
        components.path += request.path
        var queryItems = request.queryItems
        queryItems.append(URLQueryItem(name: "api_key", value: configuration.apiKey))
        components.queryItems = queryItems
        guard let url = components.url else {
            throw .invalidURL
        }
        return url
    }

    private func buildURLRequest(url: URL, request: HTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        request.headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
        return urlRequest
    }

    private func execute(_ urlRequest: URLRequest) async throws(NetworkError) -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            if error.code == .notConnectedToInternet {
                throw .noConnectivity
            }
            throw .transportError(error)
        } catch {
            throw .transportError(URLError(.unknown))
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw .serverError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws(NetworkError) -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw .decodingError(error)
        } catch {
            throw .decodingError(.dataCorrupted(.init(codingPath: [], debugDescription: error.localizedDescription)))
        }
    }
}

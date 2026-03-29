import Foundation
import Networking

final class MockHTTPClient: HTTPClient {
    var stubbedJSONData: Data?
    var stubbedError: Error?
    var fetchImageResult: Result<Data, Error> = .success(Data())

    private(set) var lastExecutedPath: String?
    private(set) var lastExecutedQueryItems: [URLQueryItem] = []
    private(set) var lastImageRequest: ImageRequest?

    func execute<Response: Decodable>(_ request: Request<Response>) async throws -> Response {
        lastExecutedPath = request.path
        lastExecutedQueryItems = request.queryItems
        if let error = stubbedError {
            throw error
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: stubbedJSONData!)
    }

    func fetchImage(_ request: ImageRequest) async throws -> Data {
        lastImageRequest = request
        return try fetchImageResult.get()
    }
}

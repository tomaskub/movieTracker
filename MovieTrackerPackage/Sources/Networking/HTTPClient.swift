import Foundation

public protocol HTTPClient {
    func execute<Response: Decodable>(_ request: Request<Response>) async throws -> Response
    func fetchImage(_ request: ImageRequest) async throws -> Data
}

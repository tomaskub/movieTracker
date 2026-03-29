import Foundation

public struct Request<Response: Decodable> {
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]

    public init(path: String, method: HTTPMethod = .get, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
    }
}

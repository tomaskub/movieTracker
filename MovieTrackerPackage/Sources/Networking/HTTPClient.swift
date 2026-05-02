import Foundation

public protocol HTTPClient {
    func fetch<T: Decodable>(_ request: HTTPRequest) async throws(NetworkError) -> T
    func fetchData(from url: URL) async throws(NetworkError) -> Data
}

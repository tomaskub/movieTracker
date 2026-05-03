import Foundation
import Networking

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var fetchResponses: [Result<Data, NetworkError>] = []
    var fetchDataResponses: [Result<Data, NetworkError>] = []

    private(set) var capturedRequests: [HTTPRequest] = []
    private(set) var capturedImageURLs: [URL] = []

    func fetch<T: Decodable>(_ request: HTTPRequest) async throws(NetworkError) -> T {
        capturedRequests.append(request)
        precondition(!fetchResponses.isEmpty, "MockHTTPClient: no fetchResponses configured for this call")
        switch fetchResponses.removeFirst() {
        case .success(let data):
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch let error as DecodingError {
                throw NetworkError.decodingError(error)
            } catch {
                fatalError("MockHTTPClient: unexpected decode error: \(error)")
            }
        case .failure(let error):
            throw error
        }
    }

    func fetchData(from url: URL) async throws(NetworkError) -> Data {
        capturedImageURLs.append(url)
        precondition(!fetchDataResponses.isEmpty, "MockHTTPClient: no fetchDataResponses configured for this call")
        switch fetchDataResponses.removeFirst() {
        case .success(let data): return data
        case .failure(let error): throw error
        }
    }
}

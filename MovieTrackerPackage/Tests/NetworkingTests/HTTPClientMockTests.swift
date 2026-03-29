import XCTest
import Networking

final class HTTPClientMockTests: XCTestCase {
    func test_consumer_callsExecuteWithExpectedRequest() async throws {
        let mock = MockHTTPClient()
        mock.executeResult = Movie(title: "Inception")

        let consumer = FakeConsumer(client: mock)
        let movie = try await consumer.fetchMovie()

        XCTAssertEqual(movie, Movie(title: "Inception"))
        XCTAssertEqual(mock.capturedExecutePath, "/movie/123")
    }

    func test_consumer_propagatesNetworkError() async {
        let mock = MockHTTPClient()
        mock.executeError = NetworkError.networkUnavailable

        let consumer = FakeConsumer(client: mock)
        do {
            _ = try await consumer.fetchMovie()
            XCTFail("Expected NetworkError.networkUnavailable")
        } catch NetworkError.networkUnavailable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct Movie: Decodable, Equatable {
    let title: String
}

private final class MockHTTPClient: HTTPClient {
    var executeResult: (any Decodable)?
    var executeError: Error?
    var capturedExecutePath: String?

    var fetchImageResult: Data?
    var fetchImageError: Error?

    func execute<Response: Decodable>(_ request: Request<Response>) async throws -> Response {
        capturedExecutePath = request.path
        if let error = executeError { throw error }
        return executeResult as! Response
    }

    func fetchImage(_ request: ImageRequest) async throws -> Data {
        if let error = fetchImageError { throw error }
        return fetchImageResult ?? Data()
    }
}

private struct FakeConsumer {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func fetchMovie() async throws -> Movie {
        try await client.execute(Request(path: "/movie/123"))
    }
}

import XCTest
@testable import Networking

final class URLSessionHTTPClientTests: XCTestCase {
    private var session: URLSession!
    private var sut: URLSessionHTTPClient!

    private let baseURL = URL(string: "https://api.themoviedb.org/3")!
    private let apiKey = "test-api-key"

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        sut = URLSessionHTTPClient(
            configuration: NetworkConfiguration(baseURL: baseURL, apiKey: apiKey),
            session: session
        )
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        sut = nil
        session = nil
        super.tearDown()
    }

    // MARK: - fetch<T>

    func test_fetch_appendsApiKeyQueryParameter() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (self.response(statusCode: 200), try self.encode(["id": 1]))
        }

        let _: TestDTO = try await sut.fetch(HTTPRequest(path: "/trending/movie/week"))

        let url = try XCTUnwrap(capturedRequest?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "api_key", value: apiKey)))
    }

    func test_fetch_appendsCallerQueryItems() async throws {
        MockURLProtocol.requestHandler = { _ in
            (self.response(statusCode: 200), try self.encode(["id": 1]))
        }
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (self.response(statusCode: 200), try self.encode(["id": 1]))
        }

        let callerItem = URLQueryItem(name: "page", value: "2")
        let _: TestDTO = try await sut.fetch(HTTPRequest(path: "/search/movie", queryItems: [callerItem]))

        let url = try XCTUnwrap(capturedRequest?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertTrue(items.contains(callerItem))
    }

    func test_fetch_decodesValidResponse() async throws {
        MockURLProtocol.requestHandler = { _ in
            (self.response(statusCode: 200), try self.encode(["id": 42]))
        }

        let result: TestDTO = try await sut.fetch(HTTPRequest(path: "/movie/42"))

        XCTAssertEqual(result.id, 42)
    }

    func test_fetch_throwsServerError_onNon2xxResponse() async {
        MockURLProtocol.requestHandler = { _ in
            (self.response(statusCode: 404), Data())
        }

        await assertThrowsNetworkError(
            try await sut.fetch(HTTPRequest(path: "/movie/0")) as TestDTO
        ) { error in
            guard case .serverError(let code) = error else { return XCTFail("Expected serverError, got \(error)") }
            XCTAssertEqual(code, 404)
        }
    }

    func test_fetch_throwsDecodingError_onMalformedJSON() async {
        MockURLProtocol.requestHandler = { _ in
            (self.response(statusCode: 200), Data("not-json".utf8))
        }

        await assertThrowsNetworkError(
            try await sut.fetch(HTTPRequest(path: "/movie/1")) as TestDTO
        ) { error in
            guard case .decodingError = error else { return XCTFail("Expected decodingError, got \(error)") }
        }
    }

    func test_fetch_throwsNoConnectivity_onNotConnectedToInternet() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        await assertThrowsNetworkError(
            try await sut.fetch(HTTPRequest(path: "/movie/1")) as TestDTO
        ) { error in
            guard case .noConnectivity = error else { return XCTFail("Expected noConnectivity, got \(error)") }
        }
    }

    func test_fetch_throwsTransportError_onOtherURLError() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }

        await assertThrowsNetworkError(
            try await sut.fetch(HTTPRequest(path: "/movie/1")) as TestDTO
        ) { error in
            guard case .transportError(let urlError) = error else { return XCTFail("Expected transportError, got \(error)") }
            XCTAssertEqual(urlError.code, .timedOut)
        }
    }

    // MARK: - fetchData

    func test_fetchData_returnsRawBytes() async throws {
        let expected = Data("image-bytes".utf8)
        let imageURL = URL(string: "https://image.tmdb.org/t/p/w500/poster.jpg")!
        MockURLProtocol.requestHandler = { _ in (self.response(statusCode: 200), expected) }

        let result = try await sut.fetchData(from: imageURL)

        XCTAssertEqual(result, expected)
    }

    func test_fetchData_doesNotAppendApiKey() async throws {
        var capturedRequest: URLRequest?
        let imageURL = URL(string: "https://image.tmdb.org/t/p/w500/poster.jpg")!
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (self.response(statusCode: 200), Data())
        }

        _ = try await sut.fetchData(from: imageURL)

        let url = try XCTUnwrap(capturedRequest?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertFalse(items.contains(where: { $0.name == "api_key" }))
    }

    func test_fetchData_throwsServerError_onNon2xxResponse() async {
        let imageURL = URL(string: "https://image.tmdb.org/t/p/w500/missing.jpg")!
        MockURLProtocol.requestHandler = { _ in (self.response(statusCode: 500), Data()) }

        await assertThrowsNetworkError(
            try await sut.fetchData(from: imageURL)
        ) { error in
            guard case .serverError(let code) = error else { return XCTFail("Expected serverError, got \(error)") }
            XCTAssertEqual(code, 500)
        }
    }

    // MARK: - Helpers

    private func response(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: baseURL, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func assertThrowsNetworkError<T>(
        _ expression: @autoclosure () async throws(NetworkError) -> T,
        file: StaticString = #filePath,
        line: UInt = #line,
        verify: (NetworkError) -> Void
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected NetworkError to be thrown", file: file, line: line)
        } catch {
            verify(error)
        }
    }
}

private struct TestDTO: Decodable {
    let id: Int
}

import XCTest
@testable import Networking

final class URLSessionHTTPClientTests: XCTestCase {
    private let baseURL = URL(string: "https://api.example.com/3")!
    private let imageBaseURL = URL(string: "https://image.example.com/t/p")!
    private let apiKey = "test-api-key"

    private func makeClient() -> URLSessionHTTPClient {
        URLSessionHTTPClient(
            baseURL: baseURL,
            imageBaseURL: imageBaseURL,
            apiKey: apiKey,
            session: MockURLProtocol.makeSession()
        )
    }

    private func makeResponse(statusCode: Int, url: URL? = nil) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url ?? baseURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    func test_execute_returnsDecodedResponse_on2xxWithValidJSON() async throws {
        struct Item: Decodable, Equatable {
            let someValue: String
        }

        let json = #"{"some_value":"hello"}"#.data(using: .utf8)!
        MockURLProtocol.requestHandler = { _ in (self.makeResponse(statusCode: 200), json) }

        let client = makeClient()
        let result: Item = try await client.execute(Request(path: "/items"))
        XCTAssertEqual(result, Item(someValue: "hello"))
    }

    func test_execute_throwsServerError_on4xxResponse() async {
        MockURLProtocol.requestHandler = { _ in (self.makeResponse(statusCode: 404), Data()) }

        let client = makeClient()
        do {
            let _: EmptyResponse = try await client.execute(Request(path: "/items"))
            XCTFail("Expected NetworkError.serverError")
        } catch NetworkError.serverError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_execute_throwsServerError_on5xxResponse() async {
        MockURLProtocol.requestHandler = { _ in (self.makeResponse(statusCode: 500), Data()) }

        let client = makeClient()
        do {
            let _: EmptyResponse = try await client.execute(Request(path: "/items"))
            XCTFail("Expected NetworkError.serverError")
        } catch NetworkError.serverError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_execute_throwsNetworkUnavailable_onNotConnectedToInternet() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        let client = makeClient()
        do {
            let _: EmptyResponse = try await client.execute(Request(path: "/items"))
            XCTFail("Expected NetworkError.networkUnavailable")
        } catch NetworkError.networkUnavailable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_execute_throwsNetworkUnavailable_onNetworkConnectionLost() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.networkConnectionLost) }

        let client = makeClient()
        do {
            let _: EmptyResponse = try await client.execute(Request(path: "/items"))
            XCTFail("Expected NetworkError.networkUnavailable")
        } catch NetworkError.networkUnavailable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_execute_throwsServerError_onMalformedJSON() async {
        let malformed = "not json".data(using: .utf8)!
        MockURLProtocol.requestHandler = { _ in (self.makeResponse(statusCode: 200), malformed) }

        let client = makeClient()
        do {
            let _: EmptyResponse = try await client.execute(Request(path: "/items"))
            XCTFail("Expected NetworkError.serverError")
        } catch NetworkError.serverError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_fetchImage_returnsData_on2xxWithBody() async throws {
        let imageData = Data([0xFF, 0xD8, 0xFF])
        MockURLProtocol.requestHandler = { _ in (self.makeResponse(statusCode: 200), imageData) }

        let client = makeClient()
        let result = try await client.fetchImage(ImageRequest(path: "/abc123.jpg", sizeVariant: "w500"))
        XCTAssertEqual(result, imageData)
    }

    func test_fetchImage_throwsServerError_onEmptyBody() async {
        MockURLProtocol.requestHandler = { _ in (self.makeResponse(statusCode: 200), Data()) }

        let client = makeClient()
        do {
            _ = try await client.fetchImage(ImageRequest(path: "/abc123.jpg", sizeVariant: "w500"))
            XCTFail("Expected NetworkError.serverError")
        } catch NetworkError.serverError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_execute_appendsApiKey_toEveryRequest() async throws {
        let json = #"{"some_value":"x"}"#.data(using: .utf8)!
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (self.makeResponse(statusCode: 200), json)
        }

        struct Item: Decodable { let someValue: String }
        let client = makeClient()
        let _: Item = try await client.execute(Request(path: "/items"))

        let url = try XCTUnwrap(capturedRequest?.url)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let apiKeyItem = components?.queryItems?.first(where: { $0.name == "api_key" })
        XCTAssertEqual(apiKeyItem?.value, apiKey)
    }

    func test_fetchImage_doesNotAppendApiKey() async throws {
        let imageData = Data([0xFF, 0xD8, 0xFF])
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (self.makeResponse(statusCode: 200), imageData)
        }

        let client = makeClient()
        _ = try await client.fetchImage(ImageRequest(path: "/abc123.jpg", sizeVariant: "w500"))

        let url = try XCTUnwrap(capturedRequest?.url)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let apiKeyItem = components?.queryItems?.first(where: { $0.name == "api_key" })
        XCTAssertNil(apiKeyItem)
    }
}

private struct EmptyResponse: Decodable {}

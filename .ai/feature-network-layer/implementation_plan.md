# Implementation Plan — Networking Layer

## Overview

Implement a standalone `Networking` Swift Package Manager library target inside `MovieTrackerPackage`. The target is pure `Foundation`, has zero domain knowledge, and exposes the transport seam (`HTTPClient` protocol) behind which the concrete `URLSession`-backed implementation lives. A companion test target covers all acceptance criteria from the PRD.

---

## Step 1 — Add `Networking` and `NetworkingTests` targets to `Package.swift`

**File:** `MovieTrackerPackage/Package.swift`

1. Add a `.library` product named `Networking` backed by a target of the same name.
2. Add a `.target` named `Networking` with no dependencies (Foundation is implicit).
3. Add a `.testTarget` named `NetworkingTests` depending on `Networking`.

No third-party packages are introduced.

---

## Step 2 — Create source directory structure

Create the following empty directories (Swift files will be added in subsequent steps):

```
MovieTrackerPackage/Sources/Networking/
MovieTrackerPackage/Tests/NetworkingTests/
```

---

## Step 3 — Implement `HTTPMethod`

**File:** `Sources/Networking/HTTPMethod.swift`

- Define `enum HTTPMethod: String` with case `.get = "GET"`.
- `String` raw value makes it trivial to set `URLRequest.httpMethod` without a switch.

---

## Step 4 — Implement `Request<Response>`

**File:** `Sources/Networking/Request.swift`

- Define `struct Request<Response: Decodable>`.
- Stored properties: `path: String`, `method: HTTPMethod`, `queryItems: [URLQueryItem]`.
- Provide a convenience `init` with `queryItems` defaulting to `[]`.

---

## Step 5 — Implement `ImageRequest`

**File:** `Sources/Networking/ImageRequest.swift`

- Define `struct ImageRequest`.
- Stored properties: `path: String`, `sizeVariant: String`.

---

## Step 6 — Implement `NetworkError`

**File:** `Sources/Networking/NetworkError.swift`

- Define `enum NetworkError: Error` with cases `networkUnavailable` and `serverError`.
- No associated values; underlying errors are not surfaced.

---

## Step 7 — Define `HTTPClient` protocol

**File:** `Sources/Networking/HTTPClient.swift`

- Define `protocol HTTPClient`.
- Method `execute<Response: Decodable>(_ request: Request<Response>) async throws -> Response`.
- Method `fetchImage(_ request: ImageRequest) async throws -> Data`.
- Both methods throw `NetworkError` exclusively (document in protocol with a comment only if not self-evident from the signature).

---

## Step 8 — Implement `URLSessionHTTPClient`

**File:** `Sources/Networking/URLSessionHTTPClient.swift`

This is the concrete implementation. All stored properties are `private let` (immutable after init, satisfying the concurrency requirement).

**8.1 Initialiser**

```swift
init(baseURL: URL, imageBaseURL: URL, apiKey: String, session: URLSession = .shared)
```

Store all four parameters as private constants. `apiKey` is never exposed in any public interface.

**8.2 `execute(_:)` implementation**

1. Append `request.path` to `baseURL` using `URL(string:relativeTo:)` or component-based construction.
2. Build `URLComponents` from the resulting URL; append `request.queryItems` plus `URLQueryItem(name: "api_key", value: apiKey)`.
3. Construct a `URLRequest`; set `httpMethod = request.method.rawValue`.
4. Call `session.data(for:)` (async).
5. Check `HTTPURLResponse.statusCode`; any non-2xx maps to `NetworkError.serverError`.
6. Decode the body with a `JSONDecoder` configured with `.convertFromSnakeCase`; a decoding failure maps to `NetworkError.serverError`.
7. Catch `URLError` codes `.notConnectedToInternet` and `.networkConnectionLost` → `NetworkError.networkUnavailable`; all other errors → `NetworkError.serverError`.

**8.3 `fetchImage(_:)` implementation**

1. Build the URL: `imageBaseURL` / `sizeVariant` / `path` (path components appended in order).
2. The `api_key` query parameter is **not** added.
3. Call `session.data(for:)` (async).
4. Check `HTTPURLResponse.statusCode`; any non-2xx → `NetworkError.serverError`.
5. Guard that `data.isEmpty == false`; empty body → `NetworkError.serverError`.
6. Return raw `Data`.
7. Same error mapping as `execute`.

**8.4 Private helpers**

- Extract a `private func mapError(_ error: Error) -> NetworkError` that centralises the `URLError` → `NetworkError` mapping. Both public methods call this helper from their `catch` blocks.
- Extract a `private func validateStatusCode(_ response: URLResponse) throws` that checks the HTTP status code, throwing `NetworkError.serverError` when not 2xx.

---

## Step 9 — Write `NetworkingTests`

All tests use `XCTest`. No mocking framework is introduced. A local `MockURLProtocol` subclass stubs network responses within the test target.

### 9.1 `MockURLProtocol`

**File:** `Tests/NetworkingTests/MockURLProtocol.swift`

- Subclass `URLProtocol`.
- Static handler closure: `static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?`
- Override `canInit`, `canonicalRequest`, `startLoading`, `stopLoading`.
- `startLoading` calls the handler and feeds the result (or error) back to the client.

A factory helper creates a `URLSession` wired to use `MockURLProtocol`:

```swift
static func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}
```

### 9.2 `URLSessionHTTPClientTests`

**File:** `Tests/NetworkingTests/URLSessionHTTPClientTests.swift`

One `XCTestCase` subclass. Each test method creates a fresh `URLSessionHTTPClient` with `MockURLProtocol`-backed session.

| Test method | PRD AC | What it asserts |
|---|---|---|
| `test_execute_returnsDecodedResponse_on2xxWithValidJSON` | AC-1 | Response is correctly decoded |
| `test_execute_throwsServerError_on4xxResponse` | AC-2 | `NetworkError.serverError` on 4xx |
| `test_execute_throwsServerError_on5xxResponse` | AC-2 | `NetworkError.serverError` on 5xx |
| `test_execute_throwsNetworkUnavailable_onNotConnectedToInternet` | AC-3 | `NetworkError.networkUnavailable` |
| `test_execute_throwsNetworkUnavailable_onNetworkConnectionLost` | AC-3 | `NetworkError.networkUnavailable` |
| `test_execute_throwsServerError_onMalformedJSON` | AC-4 | `NetworkError.serverError` on decode failure |
| `test_fetchImage_returnsData_on2xxWithBody` | AC-5 | Returns raw `Data` |
| `test_fetchImage_throwsServerError_onEmptyBody` | AC-6 | `NetworkError.serverError` on empty data |
| `test_execute_appendsApiKey_toEveryRequest` | AC-7 | URL contains `api_key` query item |
| `test_fetchImage_doesNotAppendApiKey` | AC-7 | Image URL does not contain `api_key` |

Helper: `private func makeClient(...) -> URLSessionHTTPClient` for DRY setup.

### 9.3 `HTTPClientMockTests` (seam isolation)

**File:** `Tests/NetworkingTests/HTTPClientMockTests.swift`

Demonstrates AC-8: a consumer that depends only on `HTTPClient` can be fully tested without importing the concrete implementation.

- Define a `MockHTTPClient: HTTPClient` locally in the test file.
- Write a trivial `FakeConsumer` that receives `HTTPClient` via init (dependency injection).
- Assert that `FakeConsumer` calls `execute` with the expected `Request` and that `FakeConsumer` handles the returned value or thrown error correctly.
- This test file imports only `Networking`; it never references `URLSessionHTTPClient`.

---

## Step 10 — Validate acceptance criteria coverage

Walk through the PRD acceptance criteria and confirm each is covered:

| AC | Test method(s) |
|----|---------------|
| AC-1 | `test_execute_returnsDecodedResponse_on2xxWithValidJSON` |
| AC-2 | `test_execute_throwsServerError_on4xxResponse`, `…on5xxResponse` |
| AC-3 | `test_execute_throwsNetworkUnavailable_onNotConnectedToInternet`, `…onNetworkConnectionLost` |
| AC-4 | `test_execute_throwsServerError_onMalformedJSON` |
| AC-5 | `test_fetchImage_returnsData_on2xxWithBody` |
| AC-6 | `test_fetchImage_throwsServerError_onEmptyBody` |
| AC-7 | `test_execute_appendsApiKey_toEveryRequest`, `test_fetchImage_doesNotAppendApiKey` |
| AC-8 | `HTTPClientMockTests` (full file) |

---

## Step 11 — Build and run tests

1. Build the `Networking` target to confirm zero compiler errors.
2. Run `NetworkingTests`; all tests must pass.
3. Confirm no warnings about unused imports or access control.

---

## File map (final state)

```
MovieTrackerPackage/
├── Package.swift                                      ← updated (Steps 1)
├── Sources/
│   └── Networking/
│       ├── HTTPMethod.swift                           ← Step 3
│       ├── Request.swift                              ← Step 4
│       ├── ImageRequest.swift                         ← Step 5
│       ├── NetworkError.swift                         ← Step 6
│       ├── HTTPClient.swift                           ← Step 7
│       └── URLSessionHTTPClient.swift                 ← Step 8
└── Tests/
    └── NetworkingTests/
        ├── MockURLProtocol.swift                      ← Step 9.1
        ├── URLSessionHTTPClientTests.swift            ← Step 9.2
        └── HTTPClientMockTests.swift                  ← Step 9.3
```

---

## Out of scope (per PRD §7)

- Caching, retry, pagination, auth beyond `api_key`.
- Any domain models, TMDB-specific paths, or UI components.
- Wiring `URLSessionHTTPClient` into any app target or VIPER module.

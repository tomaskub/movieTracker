# Implementation Plan — TMDB Client

## Overview

Implement a standalone `TMDBClient` Swift Package Manager library target inside `MovieTrackerPackage`. The target depends on the already-implemented `Networking` library for `HTTPClient`, `Request`, `ImageRequest`, and `NetworkError`. It exposes a typed protocol plus a concrete `async/await` implementation. A companion test target covers all acceptance criteria from the client spec.

---

## Step 1 — Add `TMDBClient` and `TMDBClientTests` targets to `Package.swift`

**File:** `MovieTrackerPackage/Package.swift`

1. Add a `.library` product named `TMDBClient` backed by a target of the same name.
2. Add a `.target` named `TMDBClient` with `dependencies: ["Networking"]`.
3. Add a `.testTarget` named `TMDBClientTests` depending on `["TMDBClient", "Networking"]`.

No third-party packages are introduced.

---

## Step 2 — Create source directory structure

Create the following directories (Swift files are added in subsequent steps):

```
MovieTrackerPackage/Sources/TMDBClient/
MovieTrackerPackage/Tests/TMDBClientTests/
```

---

## Step 3 — Implement `ClientError`

**File:** `Sources/TMDBClient/ClientError.swift`

- Define `public enum ClientError: Error` with cases `networkUnavailable` and `serverError`.
- This is `TMDBClient`'s own public error type. Callers never interact with `NetworkError` directly.

```swift
public enum ClientError: Error {
    case networkUnavailable
    case serverError
}
```

---

## Step 4 — Implement public domain models

All types are `public struct` conforming to `Decodable`. All nullable TMDB fields are `Optional`. The `JSONDecoder` in the networking layer is configured with `.convertFromSnakeCase`, so Swift camelCase property names automatically map from TMDB snake_case JSON keys.

### Step 4.1 — `Genre`

**File:** `Sources/TMDBClient/Models/Genre.swift`

```swift
public struct Genre: Decodable, Equatable {
    public let id: Int
    public let name: String
}
```

### Step 4.2 — `Movie`

**File:** `Sources/TMDBClient/Models/Movie.swift`

Properties: `id: Int`, `title: String`, `overview: String?`, `releaseDate: String?`, `genreIds: [Int]`, `posterPath: String?`, `voteAverage: Double`.

`genreIds` maps from JSON key `genre_ids`. The decoder's `.convertFromSnakeCase` handles this automatically.

### Step 4.3 — `MovieDetail`

**File:** `Sources/TMDBClient/Models/MovieDetail.swift`

Properties: `id: Int`, `title: String`, `overview: String?`, `releaseDate: String?`, `genres: [Genre]`, `posterPath: String?`, `voteAverage: Double`, `runtime: Int?`.

Note: `genres` is `[Genre]` (full objects with id and name), not ids — this matches the `/movie/{id}` response shape.

### Step 4.4 — `CastMember`

**File:** `Sources/TMDBClient/Models/CastMember.swift`

Public type: `id: Int`, `name: String`, `character: String?`, `profilePath: String?`.

Does **not** expose the TMDB `order` field; that is an internal implementation detail used only during decoding and sorting (see Step 7).

---

## Step 5 — Implement `ImageSize`

**File:** `Sources/TMDBClient/ImageSize.swift`

- Define `public enum ImageSize` with cases `thumbnail`, `medium`, `original`.
- Add an internal computed property `var sizeVariant: String` that maps to the TMDB size string:
  - `thumbnail` → `"w185"`
  - `medium` → `"w500"`
  - `original` → `"original"`

This mapping is the only place these TMDB-specific strings appear. The networking layer has no knowledge of them.

---

## Step 6 — Define `TMDBClient` protocol

**File:** `Sources/TMDBClient/TMDBClient.swift`

Define `public protocol TMDBClient`. All methods are `async throws` and throw `ClientError` exclusively. Methods follow the constraints from the spec: page 1 is hardcoded, no sort/filter parameters, no caching.

```swift
public protocol TMDBClient {
    func fetchTrendingMovies() async throws(ClientError) -> [Movie]
    func searchMovies(query: String) async throws(ClientError) -> [Movie]
    func fetchMovieDetail(id: Int) async throws(ClientError) -> MovieDetail
    func fetchMovieCredits(id: Int) async throws(ClientError) -> [CastMember]
    func fetchGenres() async throws(ClientError) -> [Genre]
    func fetchImage(path: String, size: ImageSize) async throws(ClientError) -> Data
}
```

> **Note on typed throws:** Swift 5.9 (as specified in the tech stack) supports typed throws (`throws(ClientError)`). If the compiler target does not support typed throws, fall back to untyped `throws` with documented semantics that only `ClientError` is thrown.

---

## Step 7 — Implement `LiveTMDBClient`

**File:** `Sources/TMDBClient/LiveTMDBClient.swift`

This is the concrete implementation. It is injected with an `HTTPClient` at construction time and has no direct dependency on `URLSession` or any transport primitive.

### Step 7.1 — Initializer

```swift
public final class LiveTMDBClient: TMDBClient {
    private let httpClient: any HTTPClient

    public init(httpClient: any HTTPClient) {
        self.httpClient = httpClient
    }
}
```

### Step 7.2 — Private internal response wrappers

These `private` (or `fileprivate`) types are used only for JSON decoding; they are never exposed publicly.

```
PagedResponse<T: Decodable>
    results: [T]

CreditsResponse
    cast: [CastMemberRaw]

GenresResponse
    genres: [Genre]

CastMemberRaw            // internal decoding type, includes billing order
    id: Int
    name: String
    character: String?
    profilePath: String?
    order: Int
```

All conform to `Decodable`; the decoder's `.convertFromSnakeCase` handles field name mapping.

### Step 7.3 — `fetchTrendingMovies`

1. Build `Request<PagedResponse<Movie>>(path: "/trending/movie/week", method: .get)`.
2. Call `httpClient.execute(request)`.
3. Return `response.results`.
4. Catch errors via the shared `mapError` helper (Step 7.8).

### Step 7.4 — `searchMovies(query:)`

1. Build `Request<PagedResponse<Movie>>(path: "/search/movie", method: .get, queryItems: [URLQueryItem(name: "query", value: query)])`.
2. Execute and return `response.results`.
3. Error mapped via `mapError`.

### Step 7.5 — `fetchMovieDetail(id:)`

1. Build `Request<MovieDetail>(path: "/movie/\(id)", method: .get)`.
2. Execute and return the decoded `MovieDetail` directly (no wrapper needed; the response root is the object).
3. Error mapped via `mapError`.

### Step 7.6 — `fetchMovieCredits(id:)`

1. Build `Request<CreditsResponse>(path: "/movie/\(id)/credits", method: .get)`.
2. Execute to get `CreditsResponse`.
3. Sort `response.cast` ascending by `CastMemberRaw.order`.
4. Map each `CastMemberRaw` to `CastMember` (drop `order`).
5. Return the mapped array.
6. Error mapped via `mapError`.

### Step 7.7 — `fetchGenres`

1. Build `Request<GenresResponse>(path: "/genre/movie/list", method: .get)`.
2. Execute and return `response.genres`.
3. Error mapped via `mapError`.

### Step 7.8 — `fetchImage(path:size:)`

1. Construct `ImageRequest(path: path, sizeVariant: size.sizeVariant)`.
2. Call `httpClient.fetchImage(imageRequest)`.
3. Return raw `Data`.
4. Error mapped via `mapError`.

### Step 7.9 — `mapError` private helper

```swift
private func mapError(_ error: Error) -> ClientError {
    switch error as? NetworkError {
    case .networkUnavailable: return .networkUnavailable
    default: return .serverError
    }
}
```

All six method implementations `catch` errors and rethrow via this helper, ensuring callers never receive `NetworkError`.

---

## Step 8 — Implement `MockHTTPClient` for tests

**File:** `Tests/TMDBClientTests/MockHTTPClient.swift`

A test-local `MockHTTPClient: HTTPClient` that allows configuring stub behavior per test:

```swift
final class MockHTTPClient: HTTPClient {
    var executeResult: Any?         // set to a Decodable value or Error
    var fetchImageResult: Result<Data, Error> = .success(Data())

    var lastExecutedRequest: Any?   // stores the last Request passed in
    var lastImageRequest: ImageRequest?

    func execute<Response: Decodable>(_ request: Request<Response>) async throws -> Response { ... }
    func fetchImage(_ request: ImageRequest) async throws -> Data { ... }
}
```

- `execute` checks `executeResult`: if it's an `Error`, throws it; otherwise casts and returns.
- `fetchImageResult` drives `fetchImage`.
- Captures last request for assertion.

---

## Step 9 — Write `TMDBClientTests`

**File:** `Tests/TMDBClientTests/LiveTMDBClientTests.swift`

All tests use `XCTest`. Each test creates a fresh `MockHTTPClient` and `LiveTMDBClient` instance.

### Test matrix

| Test method | What it verifies |
|---|---|
| `test_fetchTrendingMovies_returnsMovies_onSuccess` | Decoded `[Movie]` from `results` array is returned |
| `test_fetchTrendingMovies_usesCorrectEndpoint` | `Request.path == "/trending/movie/week"` |
| `test_fetchTrendingMovies_throwsNetworkUnavailable_onNetworkError` | `NetworkError.networkUnavailable` → `ClientError.networkUnavailable` |
| `test_fetchTrendingMovies_throwsServerError_onServerError` | `NetworkError.serverError` → `ClientError.serverError` |
| `test_searchMovies_returnsMovies_onSuccess` | Decoded `[Movie]` returned for a valid query |
| `test_searchMovies_passesQueryInRequest` | `Request.queryItems` contains `URLQueryItem(name: "query", value: ...)` |
| `test_searchMovies_throwsServerError_onFailure` | Error mapping for search |
| `test_fetchMovieDetail_returnsMovieDetail_onSuccess` | Full `MovieDetail` decoded and returned |
| `test_fetchMovieDetail_usesCorrectEndpoint` | `Request.path == "/movie/\(id)"` |
| `test_fetchMovieDetail_throwsServerError_onFailure` | Error mapping for detail fetch |
| `test_fetchMovieCredits_returnsCastSortedByOrder` | Cast is sorted ascending by TMDB `order` field, regardless of JSON order |
| `test_fetchMovieCredits_usesCorrectEndpoint` | `Request.path == "/movie/\(id)/credits"` |
| `test_fetchMovieCredits_throwsNetworkUnavailable_onNetworkError` | Error mapping for credits |
| `test_fetchGenres_returnsGenres_onSuccess` | Decoded `[Genre]` array returned |
| `test_fetchGenres_usesCorrectEndpoint` | `Request.path == "/genre/movie/list"` |
| `test_fetchGenres_throwsServerError_onFailure` | Error mapping for genres |
| `test_fetchImage_thumbnail_usesThumbnailSizeVariant` | `ImageRequest.sizeVariant == "w185"` |
| `test_fetchImage_medium_usesMediumSizeVariant` | `ImageRequest.sizeVariant == "w500"` |
| `test_fetchImage_original_usesOriginalSizeVariant` | `ImageRequest.sizeVariant == "original"` |
| `test_fetchImage_returnsData_onSuccess` | Raw `Data` returned unchanged |
| `test_fetchImage_throwsNetworkUnavailable_onNetworkError` | Error mapping for image fetch |
| `test_fetchImage_throwsServerError_onServerError` | Error mapping for image server error |

### Notes on key tests

**`test_fetchMovieCredits_returnsCastSortedByOrder`**: Provide a `CreditsResponse` JSON where cast members are out of billing order (e.g., order values 2, 0, 1). Assert the returned array has members sorted 0, 1, 2.

**Error mapping tests**: Configure `MockHTTPClient` to throw `NetworkError.networkUnavailable` or `NetworkError.serverError`. Assert the method rethrows exactly `ClientError.networkUnavailable` or `ClientError.serverError` respectively using `XCTAssertThrowsError`.

---

## Step 10 — Validate acceptance criteria coverage

| Client Spec requirement | Test method(s) covering it |
|---|---|
| `fetchTrendingMovies` returns `[Movie]` or `ClientError` | `test_fetchTrendingMovies_returnsMovies_onSuccess`, `_throwsNetworkUnavailable_*`, `_throwsServerError_*` |
| `searchMovies` passes `query` param | `test_searchMovies_passesQueryInRequest` |
| `fetchMovieDetail` uses `/movie/{id}` | `test_fetchMovieDetail_usesCorrectEndpoint` |
| `fetchMovieCredits` sorts by billing order ascending | `test_fetchMovieCredits_returnsCastSortedByOrder` |
| `fetchGenres` returns full genre catalogue | `test_fetchGenres_returnsGenres_onSuccess` |
| `fetchImage` maps `ImageSize` to correct `sizeVariant` | Three `test_fetchImage_*_uses*SizeVariant` tests |
| `ClientError.networkUnavailable` maps from `NetworkError.networkUnavailable` | `_throwsNetworkUnavailable_*` tests across all methods |
| `ClientError.serverError` maps from `NetworkError.serverError` | `_throwsServerError_*` tests across all methods |
| `TMDBClient` has no knowledge of API key | No `apiKey` handling anywhere in `TMDBClient` source; verified by absence |
| `HTTPClient` is injected; no direct `URLSession` dependency | Constructor injection confirmed by `LiveTMDBClient.init(httpClient:)` |

---

## Step 11 — Build and run tests

**Note:** All build and test actions must be performed using xcode mcp or xcodebuild command. No swift build is allowed.
1. Build the `TMDBClient` target — zero compiler errors.
2. Run `TMDBClientTests` — all tests pass.
3. Confirm no warnings about unused imports or access control.

---

## File map (final state)

```
MovieTrackerPackage/
├── Package.swift                                           ← updated (Step 1)
├── Sources/
│   └── TMDBClient/
│       ├── ClientError.swift                               ← Step 3
│       ├── ImageSize.swift                                 ← Step 5
│       ├── TMDBClient.swift                                ← Step 6
│       ├── LiveTMDBClient.swift                            ← Step 7
│       └── Models/
│           ├── Genre.swift                                 ← Step 4.1
│           ├── Movie.swift                                 ← Step 4.2
│           ├── MovieDetail.swift                           ← Step 4.3
│           └── CastMember.swift                            ← Step 4.4
└── Tests/
    └── TMDBClientTests/
        ├── MockHTTPClient.swift                            ← Step 8
        └── LiveTMDBClientTests.swift                       ← Step 9
```

---

## Out of scope (per client spec)

- Caching at any layer; every call issues a network request.
- Pagination; page 1 is hardcoded and no parameter is exposed.
- Sort or filter parameters on any method; that is the caller's responsibility.
- API key handling; that is entirely the networking layer's responsibility.
- Wiring `LiveTMDBClient` into any app target or VIPER module.
- `DesignSystem` dependency; `TMDBClient` has none.

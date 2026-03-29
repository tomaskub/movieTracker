# TMDB API Client — Requirements Specification

## Package structure

Add a new library target `TMDBClient` to `MovieTrackerPackage/Package.swift`:

- `MovieTrackerPackage/Sources/TMDBClient/`
- Depends on the networking layer library (for `HTTPClient` interface, `Request`, `ImageRequest`, and `NetworkError`)
- No dependency on `DesignSystem`
- Each architectural implementation (MVVM, VIPER, TCA) imports `TMDBClient` and wraps the interface in its own idiomatic concurrency style

---

## Error model

Two cases only. `ClientError` is `TMDBClient`'s own public type; it is mapped from `NetworkError` received from the networking layer. Callers of `TMDBClient` never interact with `NetworkError` directly.

```
ClientError
  | networkUnavailable   -- mapped from NetworkError.networkUnavailable
  | serverError          -- mapped from NetworkError.serverError
```

---

## Domain models

All fields that are nullable in the TMDB response are nullable here. Callers own placeholder/fallback strategy.

```
Movie
  id:           Int
  title:        String
  overview:     String?
  releaseDate:  String?        -- ISO-8601 date string, e.g. "2024-03-15"
  genreIds:     [Int]
  posterPath:   String?        -- relative TMDB path, used internally with fetchImage
  voteAverage:  Double

MovieDetail
  id:           Int
  title:        String
  overview:     String?
  releaseDate:  String?
  genres:       [Genre]        -- full Genre objects (id + name), not ids
  posterPath:   String?
  voteAverage:  Double
  runtime:      Int?           -- minutes, nullable

CastMember
  id:           Int
  name:         String
  character:    String?
  profilePath:  String?        -- relative TMDB path, used internally with fetchImage

Genre
  id:           Int
  name:         String
```

Notes:
- `Movie` (list item) carries `genreIds` because TMDB list endpoints return ids only
- `MovieDetail` carries full `[Genre]` because `/movie/{id}` returns genre objects
- `posterPath` / `profilePath` are kept on domain models so callers can pass them to `fetchImage`; they are not raw TMDB URLs

---

## Image size

```
ImageSize
  | thumbnail    -- maps to sizeVariant "w185"
  | medium       -- maps to sizeVariant "w500"
  | original     -- maps to sizeVariant "original"
```

`ImageSize` is `TMDBClient`'s own type. The implementation maps each case to the corresponding `sizeVariant` string before constructing an `ImageRequest` for the networking layer. The networking layer has no knowledge of these values.

---

## Interface (async-agnostic)

`TMDBClient` is an interface. Each implementation wraps it using its own idiomatic concurrency style (async/await, reactive stream, callback, etc.). No async annotation is part of the contract.

Constraints applying to all methods:
- Page 1 is hardcoded; no pagination parameter is exposed
- No sort or filter parameters; all sorting/filtering is the caller's responsibility
- No caching at any layer; each call issues a network request
- API key handling is entirely the networking layer's responsibility; `TMDBClient` has no knowledge of it

---

**fetchTrendingMovies**
- *Input parameters:* none
- *Returns:* list of `Movie` or `ClientError` — first page of weekly trending movies in TMDB order

---

**searchMovies**
- *Input parameters:* `query` (String) — the title search term
- *Returns:* list of `Movie` or `ClientError` — first page of matching results; no server-side filtering applied

---

**fetchMovieDetail**
- *Input parameters:* `id` (Int) — TMDB movie identifier
- *Returns:* `MovieDetail` or `ClientError`

---

**fetchMovieCredits**
- *Input parameters:* `id` (Int) — TMDB movie identifier
- *Returns:* list of `CastMember` or `ClientError` — ordered ascending by TMDB billing `order` field

---

**fetchGenres**
- *Input parameters:* none
- *Returns:* list of `Genre` or `ClientError` — full TMDB genre catalogue

---

**fetchImage**
- *Input parameters:* `path` (String) — relative TMDB image path as found on a domain model; `size` (`ImageSize`) — requested size variant
- *Returns:* `Data` or `ClientError` — raw image data returned by the networking layer; decoding into a display-ready image is the caller's responsibility

---

## Internal implementation notes (not part of the public contract)

- The `HTTPClient` interface is injected at construction time; `TMDBClient` has no direct dependency on `URLSession` or any transport primitive
- Trending endpoint: `GET /trending/movie/week`
- Each method builds a `Request<Response>` with the appropriate path and query items, then delegates execution to the injected `HTTPClient`
- `fetchImage` maps `ImageSize` to a `sizeVariant` string, constructs an `ImageRequest`, and delegates to `HTTPClient.fetchImage`; URL construction and auth are the networking layer's concern
- `fetchMovieCredits` sorts the decoded cast array ascending by TMDB billing `order` field before mapping to `CastMember` and returning

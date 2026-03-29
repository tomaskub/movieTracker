# TMDB API Client — Requirements Specification

## Package structure

Add a new library target `TMDBClient` to `MovieTrackerPackage/Package.swift`:

- `MovieTrackerPackage/Sources/TMDBClient/`
- Depends on nothing else in the package (no DesignSystem dependency)
- Each architectural implementation (MVVM, VIPER, TCA) imports `TMDBClient` and wraps the interface in its own idiomatic concurrency style

---

## Error model

Two cases only. All HTTP 4xx/5xx and JSON decoding failures collapse into `serverError`.

```
ClientError
  | networkUnavailable   -- no connectivity / transport failure
  | serverError          -- HTTP error, decoding failure, or any other server-side fault
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
  | thumbnail    -- maps to TMDB w185
  | medium       -- maps to TMDB w500
  | original     -- maps to TMDB original
```

The size-to-TMDB-token mapping is an internal implementation detail of the client.

---

## Interface (async-agnostic)

`TMDBClient` is an interface. Each implementation wraps it using its own idiomatic concurrency style (async/await, reactive stream, callback, etc.). No async annotation is part of the contract.

Constraints applying to all methods:
- Page 1 is hardcoded; no pagination parameter is exposed
- No sort or filter parameters; all sorting/filtering is the caller's responsibility
- No caching at any layer; each call issues a network request
- API key is injected at construction time and must not appear in any public method signature

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
- *Returns:* platform image or `ClientError` — decoded image ready for display; the caller never handles a URL

---

## Internal implementation notes (not part of the public contract)

- TMDB base URL: `https://api.themoviedb.org/3`
- Image base URL: `https://image.tmdb.org/t/p/{size}/{path}`
- Auth: API key appended as query parameter `api_key=<value>` on every request
- Trending endpoint: `GET /trending/movie/week`
- `fetchImage` constructs the full TMDB image URL internally and returns decoded image data; the caller never sees a URL

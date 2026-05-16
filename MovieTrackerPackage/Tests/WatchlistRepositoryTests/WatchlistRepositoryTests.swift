import DomainModels
import Foundation
import PersistenceKit
import SwiftData
import XCTest
@testable import WatchlistRepository

@MainActor
private final class MockWatchlistEntryStoring: WatchlistEntryStoring {
    var entries: [WatchlistEntryEntity] = []
    var insertError: Error?
    var fetchError: Error?
    var deleteError: Error?

    func insert(_ entry: WatchlistEntryEntity) throws {
        if let insertError { throw insertError }
        if entries.contains(where: { $0.movieId == entry.movieId }) {
            throw PersistenceError.duplicateEntry
        }
        entries.append(entry)
    }

    func fetch(predicate: Predicate<WatchlistEntryEntity>?) throws -> [WatchlistEntryEntity] {
        if let fetchError { throw fetchError }
        guard let predicate else { return entries }
        return try entries.filter { try predicate.evaluate($0) }
    }

    func delete(movieId: Int) throws {
        if let deleteError { throw deleteError }
        guard let index = entries.firstIndex(where: { $0.movieId == movieId }) else {
            throw PersistenceError.notFound
        }
        entries.remove(at: index)
    }
}

@MainActor
final class WatchlistRepositoryTests: XCTestCase {
    private var store: MockWatchlistEntryStoring!
    private var sut: DefaultWatchlistRepository!

    override func setUp() async throws {
        store = MockWatchlistEntryStoring()
        sut = DefaultWatchlistRepository(store: store)
    }

    override func tearDown() async throws {
        sut = nil
        store = nil
    }

    func testAdd_persistsSnapshotAndMapsReleaseYearFromISODate() throws {
        let movie = Movie(
            id: 10,
            title: "Inception",
            overview: "x",
            releaseDate: "2010-07-16",
            genreIds: [],
            posterPath: "/poster.jpg",
            voteAverage: 8.8
        )
        try sut.add(movie: movie)

        let entity = try XCTUnwrap(store.entries.first { $0.movieId == 10 })
        XCTAssertEqual(entity.title, "Inception")
        XCTAssertEqual(entity.releaseYear, 2010)
        XCTAssertEqual(entity.voteAverage, 8.8)
        XCTAssertEqual(entity.posterPath, "/poster.jpg")
        XCTAssertEqual(store.entries.count, 1)
    }

    func testAdd_mapsEmptyReleaseDateToYearZero() throws {
        let movie = Movie(
            id: 11,
            title: "A",
            overview: "",
            releaseDate: "",
            genreIds: [],
            posterPath: nil,
            voteAverage: 1
        )
        try sut.add(movie: movie)
        let entity = try XCTUnwrap(store.entries.first { $0.movieId == 11 })
        XCTAssertEqual(entity.releaseYear, 0)
    }

    func testAdd_duplicateMapsToAlreadyOnWatchlist() throws {
        let movie = sampleMovie(id: 12)
        try sut.add(movie: movie)
        XCTAssertThrowsError(try sut.add(movie: movie)) { error in
            guard case .alreadyOnWatchlist = error as? WatchlistRepositoryError else {
                XCTFail("Expected alreadyOnWatchlist")
                return
            }
        }
        XCTAssertEqual(store.entries.count, 1)
    }

    func testAdd_insertFailedWrapsError() {
        store.insertError = CocoaError(.fileReadUnknown)
        XCTAssertThrowsError(try sut.add(movie: sampleMovie(id: 13))) { error in
            guard case let .insertFailed(underlying) = error as? WatchlistRepositoryError else {
                XCTFail("Expected insertFailed")
                return
            }
            XCTAssertEqual((underlying as NSError).domain, CocoaError.errorDomain)
        }
    }

    func testRemove_deletesExisting() throws {
        try sut.add(movie: sampleMovie(id: 20))
        try sut.remove(movieId: 20)
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testRemove_notFoundMapsToNotFound() {
        XCTAssertThrowsError(try sut.remove(movieId: 999)) { error in
            guard case .notFound = error as? WatchlistRepositoryError else {
                XCTFail("Expected notFound")
                return
            }
        }
    }

    func testRemove_deleteFailedWrapsNonNotFoundError() throws {
        try sut.add(movie: sampleMovie(id: 21))
        store.deleteError = CocoaError(.fileReadUnknown)
        XCTAssertThrowsError(try sut.remove(movieId: 21)) { error in
            guard case let .deleteFailed(underlying) = error as? WatchlistRepositoryError else {
                XCTFail("Expected deleteFailed")
                return
            }
            XCTAssertEqual((underlying as NSError).domain, CocoaError.errorDomain)
        }
    }

    func testFetchAll_nilSortReturnsStoreOrder() throws {
        let d1 = Date(timeIntervalSince1970: 50_000)
        let d2 = Date(timeIntervalSince1970: 60_000)
        store.entries = [
            WatchlistEntryEntity(movieId: 1, title: "B", releaseYear: 2000, voteAverage: 7, posterPath: nil, dateAdded: d1),
            WatchlistEntryEntity(movieId: 2, title: "A", releaseYear: 2000, voteAverage: 9, posterPath: nil, dateAdded: d2),
        ]
        let result = try sut.fetchAll(sortOrder: nil)
        XCTAssertEqual(result.map(\.movieId), [1, 2])
    }

    func testFetchAll_sortDateAddedNewestFirst() throws {
        let older = Date(timeIntervalSince1970: 10_000)
        let newer = Date(timeIntervalSince1970: 20_000)
        store.entries = [
            WatchlistEntryEntity(movieId: 1, title: "A", releaseYear: 2000, voteAverage: 8, posterPath: nil, dateAdded: older),
            WatchlistEntryEntity(movieId: 2, title: "B", releaseYear: 2000, voteAverage: 7, posterPath: nil, dateAdded: newer),
        ]
        let result = try sut.fetchAll(sortOrder: .dateAdded)
        XCTAssertEqual(result.map(\.movieId), [2, 1])
    }

    func testFetchAll_sortTitleAscending() throws {
        let d = Date(timeIntervalSince1970: 0)
        store.entries = [
            WatchlistEntryEntity(movieId: 1, title: "Gamma", releaseYear: 2000, voteAverage: 5, posterPath: nil, dateAdded: d),
            WatchlistEntryEntity(movieId: 2, title: "Alpha", releaseYear: 2000, voteAverage: 9, posterPath: nil, dateAdded: d),
        ]
        let result = try sut.fetchAll(sortOrder: .title)
        XCTAssertEqual(result.map(\.movieId), [2, 1])
    }

    func testFetchAll_sortVoteAverageDescending() throws {
        let d = Date(timeIntervalSince1970: 0)
        store.entries = [
            WatchlistEntryEntity(movieId: 1, title: "A", releaseYear: 2000, voteAverage: 6, posterPath: nil, dateAdded: d),
            WatchlistEntryEntity(movieId: 2, title: "B", releaseYear: 2000, voteAverage: 9.5, posterPath: nil, dateAdded: d),
        ]
        let result = try sut.fetchAll(sortOrder: .voteAverage)
        XCTAssertEqual(result.map(\.movieId), [2, 1])
    }

    func testFetchAll_fetchFailedWrapsError() {
        store.fetchError = CocoaError(.fileReadUnknown)
        XCTAssertThrowsError(try sut.fetchAll(sortOrder: nil)) { error in
            guard case let .fetchFailed(underlying) = error as? WatchlistRepositoryError else {
                XCTFail("Expected fetchFailed")
                return
            }
            XCTAssertEqual((underlying as NSError).domain, CocoaError.errorDomain)
        }
    }

    func testContains_falseWhenMissing() throws {
        XCTAssertFalse(try sut.contains(movieId: 404))
    }

    func testContains_trueWhenPresent() throws {
        try sut.add(movie: sampleMovie(id: 30))
        XCTAssertTrue(try sut.contains(movieId: 30))
    }

    func testContains_fetchFailedPropagates() {
        store.fetchError = CocoaError(.fileReadUnknown)
        XCTAssertThrowsError(try sut.contains(movieId: 1)) { error in
            guard case .fetchFailed = error as? WatchlistRepositoryError else {
                XCTFail("Expected fetchFailed")
                return
            }
        }
    }

    private func sampleMovie(id: Int) -> Movie {
        Movie(
            id: id,
            title: "T",
            overview: "",
            releaseDate: "2021-01-01",
            genreIds: [],
            posterPath: nil,
            voteAverage: 5
        )
    }
}

import XCTest
import SwiftData
@testable import PersistenceKit

@MainActor
final class PersistenceKitTests: XCTestCase {
    private var container: ModelContainer!
    private var watchlistStore: (any EntityStore<WatchlistEntryEntity>)!
    private var reviewStore: (any EntityStore<ReviewEntity>)!

    override func setUpWithError() throws {
        container = try ModelContainerProvider.makeContainer(storeType: .inMemory)
        watchlistStore = ModelContainerProvider.makeWatchlistEntryStore(container: container)
        reviewStore = ModelContainerProvider.makeReviewStore(container: container)
    }

    override func tearDownWithError() throws {
        watchlistStore = nil
        reviewStore = nil
        container = nil
    }

    // MARK: - ModelContainerProvider

    func testMakeInMemoryContainer() throws {
        let c = try ModelContainerProvider.makeContainer(storeType: .inMemory)
        XCTAssertNotNil(c)
    }

    // MARK: - Insert

    func testInsertWatchlistEntry() throws {
        let entry = makeWatchlistEntry(movieId: 1)
        try watchlistStore.insert(entry)
        let results = try watchlistStore.fetch(EntityQuery())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].movieId, 1)
    }

    func testInsertDuplicateWatchlistEntryThrowsDuplicateEntry() throws {
        let entry = makeWatchlistEntry(movieId: 42)
        try watchlistStore.insert(entry)
        do {
            try watchlistStore.insert(entry)
            XCTFail("Expected PersistenceError.duplicateEntry")
        } catch PersistenceError.duplicateEntry {
            // expected
        }
    }

    func testInsertReview() throws {
        let review = makeReview(movieId: 10)
        try reviewStore.insert(review)
        let results = try reviewStore.fetch(EntityQuery())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].movieId, 10)
    }

    func testInsertDuplicateReviewThrowsDuplicateEntry() throws {
        let review = makeReview(movieId: 10)
        try reviewStore.insert(review)
        do {
            try reviewStore.insert(review)
            XCTFail("Expected PersistenceError.duplicateEntry")
        } catch PersistenceError.duplicateEntry {
            // expected
        }
    }

    // MARK: - Update

    func testUpdateWatchlistEntry() throws {
        let original = makeWatchlistEntry(movieId: 1, title: "Original")
        try watchlistStore.insert(original)

        let updated = makeWatchlistEntry(movieId: 1, title: "Updated")
        try watchlistStore.update(updated)

        let results = try watchlistStore.fetch(EntityQuery())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Updated")
    }

    func testUpdateNonExistentWatchlistEntryThrowsNotFound() throws {
        let entry = makeWatchlistEntry(movieId: 99)
        do {
            try watchlistStore.update(entry)
            XCTFail("Expected PersistenceError.notFound")
        } catch PersistenceError.notFound {
            // expected
        }
    }

    func testUpdateReview() throws {
        let original = makeReview(movieId: 5, rating: 3)
        try reviewStore.insert(original)

        let updated = makeReview(movieId: 5, rating: 5)
        try reviewStore.update(updated)

        let results = try reviewStore.fetch(EntityQuery())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].rating, 5)
    }

    func testUpdateNonExistentReviewThrowsNotFound() throws {
        let review = makeReview(movieId: 99)
        do {
            try reviewStore.update(review)
            XCTFail("Expected PersistenceError.notFound")
        } catch PersistenceError.notFound {
            // expected
        }
    }

    // MARK: - Delete

    func testDeleteWatchlistEntry() throws {
        let entry = makeWatchlistEntry(movieId: 1)
        try watchlistStore.insert(entry)
        try watchlistStore.delete(entry)
        let results = try watchlistStore.fetch(EntityQuery())
        XCTAssertTrue(results.isEmpty)
    }

    func testDeleteNonExistentWatchlistEntryThrowsNotFound() throws {
        let entry = makeWatchlistEntry(movieId: 99)
        do {
            try watchlistStore.delete(entry)
            XCTFail("Expected PersistenceError.notFound")
        } catch PersistenceError.notFound {
            // expected
        }
    }

    func testDeleteReview() throws {
        let review = makeReview(movieId: 7)
        try reviewStore.insert(review)
        try reviewStore.delete(review)
        let results = try reviewStore.fetch(EntityQuery())
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Fetch

    func testFetchEmptyStore() throws {
        let results = try watchlistStore.fetch(EntityQuery())
        XCTAssertTrue(results.isEmpty)
    }

    func testFetchWithPredicate() throws {
        try watchlistStore.insert(makeWatchlistEntry(movieId: 1, title: "Alpha"))
        try watchlistStore.insert(makeWatchlistEntry(movieId: 2, title: "Beta"))

        let query = EntityQuery<WatchlistEntryEntity>(
            predicate: #Predicate { $0.movieId == 2 }
        )
        let results = try watchlistStore.fetch(query)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Beta")
    }

    func testFetchWithSortDescriptor() throws {
        try watchlistStore.insert(makeWatchlistEntry(movieId: 1, title: "Zorro"))
        try watchlistStore.insert(makeWatchlistEntry(movieId: 2, title: "Alpha"))

        let query = EntityQuery<WatchlistEntryEntity>(
            sortDescriptors: [SortDescriptor(\.title)]
        )
        let results = try watchlistStore.fetch(query)
        XCTAssertEqual(results.map(\.title), ["Alpha", "Zorro"])
    }

    func testFetchWithFetchLimit() throws {
        for id in 1...5 {
            try watchlistStore.insert(makeWatchlistEntry(movieId: id))
        }

        let query = EntityQuery<WatchlistEntryEntity>(fetchLimit: 3)
        let results = try watchlistStore.fetch(query)
        XCTAssertEqual(results.count, 3)
    }

    // MARK: - Helpers

    private func makeWatchlistEntry(
        movieId: Int,
        title: String = "Test Movie"
    ) -> WatchlistEntryEntity {
        WatchlistEntryEntity(
            movieId: movieId,
            title: title,
            releaseYear: 2024,
            voteAverage: 7.5,
            posterPath: nil,
            dateAdded: Date()
        )
    }

    private func makeReview(
        movieId: Int,
        rating: Int = 4
    ) -> ReviewEntity {
        ReviewEntity(
            movieId: movieId,
            rating: rating,
            tags: ["Must-see"],
            notes: "Great film",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

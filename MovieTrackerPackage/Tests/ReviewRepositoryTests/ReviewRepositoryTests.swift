import DomainModels
import Foundation
import PersistenceKit
import XCTest
@testable import ReviewRepository

@MainActor
private final class MockReviewStoring: ReviewStoring {
    var entities: [Int: ReviewEntity] = [:]
    var insertError: Error?
    var updateError: Error?
    var fetchError: Error?
    var deleteError: Error?

    func insert(_ entity: ReviewEntity) throws {
        if let insertError { throw insertError }
        if entities[entity.movieId] != nil {
            throw PersistenceError.duplicateEntry
        }
        entities[entity.movieId] = entity
    }

    func update(_ entity: ReviewEntity) throws {
        if let updateError { throw updateError }
        guard entities[entity.movieId] != nil else {
            throw PersistenceError.notFound
        }
        entities[entity.movieId] = entity
    }

    func fetch(movieId: Int) throws -> ReviewEntity? {
        if let fetchError { throw fetchError }
        return entities[movieId]
    }

    func delete(movieId: Int) throws {
        if let deleteError { throw deleteError }
        guard entities.removeValue(forKey: movieId) != nil else {
            throw PersistenceError.notFound
        }
    }
}

@MainActor
final class ReviewRepositoryTests: XCTestCase {
    private var store: MockReviewStoring!
    private var sut: DefaultReviewRepository!

    override func setUp() async throws {
        store = MockReviewStoring()
        sut = DefaultReviewRepository(store: store)
    }

    override func tearDown() async throws {
        sut = nil
        store = nil
    }

    func testCreate_insertsWithTimestampsAndTags() throws {
        try sut.create(movieId: 1, rating: 4, tags: [.funny, .dark], notes: "ok")

        let entity = store.entities[1]
        XCTAssertEqual(entity?.rating, 4)
        XCTAssertEqual(entity?.tags, ["Funny", "Dark"])
        XCTAssertEqual(entity?.notes, "ok")
        XCTAssertEqual(entity?.createdAt, entity?.updatedAt)
    }

    func testCreate_invalidRatingThrows() {
        XCTAssertThrowsError(try sut.create(movieId: 1, rating: 0, tags: [], notes: "")) { error in
            guard case .invalidRating = error as? ReviewRepositoryError else {
                XCTFail("Expected invalidRating")
                return
            }
        }
        XCTAssertTrue(store.entities.isEmpty)
    }

    func testCreate_duplicateMapsToAlreadyExists() throws {
        try sut.create(movieId: 1, rating: 3, tags: [], notes: "")
        XCTAssertThrowsError(try sut.create(movieId: 1, rating: 4, tags: [], notes: "")) { error in
            guard case .alreadyExists = error as? ReviewRepositoryError else {
                XCTFail("Expected alreadyExists")
                return
            }
        }
    }

    func testCreate_insertFailedWrapsError() {
        store.insertError = CocoaError(.fileReadUnknown)
        XCTAssertThrowsError(try sut.create(movieId: 1, rating: 3, tags: [], notes: "")) { error in
            guard case let .insertFailed(underlying) = error as? ReviewRepositoryError else {
                XCTFail("Expected insertFailed")
                return
            }
            XCTAssertEqual((underlying as NSError).domain, CocoaError.errorDomain)
        }
    }

    func testUpdate_replacesAndPreservesCreatedAt() throws {
        try sut.create(movieId: 2, rating: 2, tags: [], notes: "a")
        let originalCreated = try XCTUnwrap(store.entities[2]).createdAt
        let previousUpdated = try XCTUnwrap(store.entities[2]).updatedAt
        try sut.update(movieId: 2, rating: 5, tags: [.mustSee], notes: "b")

        let entity = store.entities[2]
        XCTAssertEqual(entity?.rating, 5)
        XCTAssertEqual(entity?.tags, ["Must-see"])
        XCTAssertEqual(entity?.notes, "b")
        XCTAssertEqual(entity?.createdAt, originalCreated)
        XCTAssertNotEqual(entity?.updatedAt, previousUpdated)
    }

    func testUpdate_invalidRatingThrows() {
        XCTAssertThrowsError(try sut.update(movieId: 1, rating: 6, tags: [], notes: "")) { error in
            guard case .invalidRating = error as? ReviewRepositoryError else {
                XCTFail("Expected invalidRating")
                return
            }
        }
    }

    func testUpdate_notFoundWhenMissing() {
        XCTAssertThrowsError(try sut.update(movieId: 99, rating: 3, tags: [], notes: "")) { error in
            guard case .notFound = error as? ReviewRepositoryError else {
                XCTFail("Expected notFound")
                return
            }
        }
    }

    func testUpdate_failedWrapsError() throws {
        try sut.create(movieId: 3, rating: 3, tags: [], notes: "")
        store.updateError = CocoaError(.fileReadUnknown)
        XCTAssertThrowsError(try sut.update(movieId: 3, rating: 4, tags: [], notes: "")) { error in
            guard case let .updateFailed(underlying) = error as? ReviewRepositoryError else {
                XCTFail("Expected updateFailed")
                return
            }
            XCTAssertEqual((underlying as NSError).domain, CocoaError.errorDomain)
        }
    }

    func testFetch_nilWhenMissing() throws {
        XCTAssertNil(try sut.fetch(movieId: 42))
    }

    func testFetch_mapsTags() throws {
        try sut.create(movieId: 5, rating: 3, tags: [.emotional], notes: "n")
        let review = try XCTUnwrap(try sut.fetch(movieId: 5))
        XCTAssertEqual(review.tags, [.emotional])
    }

    func testFetch_failedWrapsError() {
        store.fetchError = CocoaError(.fileReadUnknown)
        XCTAssertThrowsError(try sut.fetch(movieId: 1)) { error in
            guard case let .fetchFailed(underlying) = error as? ReviewRepositoryError else {
                XCTFail("Expected fetchFailed")
                return
            }
            XCTAssertEqual((underlying as NSError).domain, CocoaError.errorDomain)
        }
    }

    func testDelete_removesRow() throws {
        try sut.create(movieId: 7, rating: 3, tags: [], notes: "")
        try sut.delete(movieId: 7)
        XCTAssertNil(store.entities[7])
    }

    func testDelete_failedWrapsError() {
        XCTAssertThrowsError(try sut.delete(movieId: 1)) { error in
            guard case let .deleteFailed(underlying) = error as? ReviewRepositoryError else {
                XCTFail("Expected deleteFailed")
                return
            }
            guard case .notFound = underlying as? PersistenceError else {
                XCTFail("Expected PersistenceError.notFound")
                return
            }
        }
    }

    func testContains() throws {
        XCTAssertFalse(try sut.contains(movieId: 8))
        try sut.create(movieId: 8, rating: 3, tags: [], notes: "")
        XCTAssertTrue(try sut.contains(movieId: 8))
    }

    func testContains_propagatesFetchFailure() {
        store.fetchError = CocoaError(.fileReadUnknown)
        XCTAssertThrowsError(try sut.contains(movieId: 1)) { error in
            guard case .fetchFailed = error as? ReviewRepositoryError else {
                XCTFail("Expected fetchFailed")
                return
            }
        }
    }

    func testUpdate_fetchFailureSurfacesAsFetchFailed() {
        store.fetchError = CocoaError(.fileReadNoSuchFile)
        XCTAssertThrowsError(try sut.update(movieId: 1, rating: 3, tags: [], notes: "")) { error in
            guard case let .fetchFailed(underlying) = error as? ReviewRepositoryError else {
                XCTFail("Expected fetchFailed")
                return
            }
            XCTAssertEqual((underlying as NSError).domain, CocoaError.errorDomain)
        }
    }
}

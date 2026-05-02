import XCTest
import SwiftData
@testable import PersistenceKit

final class PersistenceKitTests: XCTestCase {
    func testMakeInMemoryContainer() throws {
        let container = try ModelContainerProvider.makeContainer(storeType: .inMemory)
        XCTAssertNotNil(container)
    }
}

import XCTest
import SwiftUI
@testable import SharedUIComponents

final class RatingFormatterTests: XCTestCase {

    func test_formatRating_oneDecimalPlace() {
        XCTAssertEqual(formatRating(7.348), "7.3")
    }

    func test_formatRating_roundsDown() {
        XCTAssertEqual(formatRating(6.94), "6.9")
    }

    func test_formatRating_roundsUp() {
        XCTAssertEqual(formatRating(6.95), "7.0")
    }

    func test_formatRating_exactDecimal() {
        XCTAssertEqual(formatRating(8.0), "8.0")
    }

    func test_formatRating_zeroRating() {
        XCTAssertEqual(formatRating(0.0), "0.0")
    }

    func test_formatRating_maxRating() {
        XCTAssertEqual(formatRating(10.0), "10.0")
    }
}

final class MovieCardImageStateTests: XCTestCase {

    func test_imageState_placeholder_isPlaceholder() {
        let state = MovieCardView.ImageState.placeholder
        if case .placeholder = state { } else {
            XCTFail("Expected .placeholder")
        }
    }

    func test_imageState_image_holdsImage() {
        let sampleImage = Image(systemName: "photo")
        let state = MovieCardView.ImageState.image(sampleImage)
        if case .image = state { } else {
            XCTFail("Expected .image")
        }
    }

    func test_imageState_placeholder_isNotImage() {
        let state = MovieCardView.ImageState.placeholder
        if case .image = state {
            XCTFail("Expected .placeholder, not .image")
        }
    }

    func test_imageState_image_isNotPlaceholder() {
        let state = MovieCardView.ImageState.image(Image(systemName: "photo"))
        if case .placeholder = state {
            XCTFail("Expected .image, not .placeholder")
        }
    }
}

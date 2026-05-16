import ReviewRepository
import SwiftUI

private enum ReviewRepositoryKey: EnvironmentKey {
    static let defaultValue: (any ReviewRepository)? = nil
}

extension EnvironmentValues {
    var reviewRepository: (any ReviewRepository)? {
        get { self[ReviewRepositoryKey.self] }
        set { self[ReviewRepositoryKey.self] = newValue }
    }
}

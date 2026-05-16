import SwiftUI
import WatchlistRepository

private enum WatchlistRepositoryKey: EnvironmentKey {
    static let defaultValue: (any WatchlistRepository)? = nil
}

extension EnvironmentValues {
    var watchlistRepository: (any WatchlistRepository)? {
        get { self[WatchlistRepositoryKey.self] }
        set { self[WatchlistRepositoryKey.self] = newValue }
    }
}

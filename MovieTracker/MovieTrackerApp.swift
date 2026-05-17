import CatalogFeature
import DesignSystem
import Networking
import PersistenceKit
import ReviewRepository
import SearchFeature
import SwiftData
import SwiftUI
import TMDBClient
import WatchlistRepository

@main
struct MovieTrackerApp: App {
    private let modelContainer: ModelContainer
    private let tmdbClient: TMDBClient
    private let watchlistRepository: DefaultWatchlistRepository
    private let reviewRepository: DefaultReviewRepository
    private let catalogRouter: CatalogRouter
    private let searchRouter: SearchRouter

    init() {
        do {
            modelContainer = try ModelContainerProvider.makeContainer(storeType: .persistent)
        } catch {
            fatalError("ModelContainer could not be created: \(error)")
        }
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String ?? ""
        let baseURL = URL(string: Bundle.main.object(forInfoDictionaryKey: "TMDBBaseURL") as? String ?? "")!
        let httpClient = URLSessionHTTPClient(
            configuration: NetworkConfiguration(baseURL: baseURL, apiKey: apiKey)
        )
        tmdbClient = TMDBClient(httpClient: httpClient)
        watchlistRepository = DefaultWatchlistRepository.make(
            entityStore: ModelContainerProvider.makeWatchlistEntryStore(container: modelContainer)
        )
        reviewRepository = DefaultReviewRepository.make(
            entityStore: ModelContainerProvider.makeReviewStore(container: modelContainer)
        )
        catalogRouter = CatalogRouter(tmdbClient: tmdbClient)
        searchRouter = SearchRouter(tmdbClient: tmdbClient)
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                catalogRouter.makeRootView()
                    .tabItem { Label("Trending", systemImage: DSIcon.catalogTab.rawValue) }
                    .tag(0)

                searchRouter.makeRootView()
                    .tabItem { Label("Search", systemImage: DSIcon.searchTab.rawValue) }
                    .tag(1)
            }
        }
    }
}

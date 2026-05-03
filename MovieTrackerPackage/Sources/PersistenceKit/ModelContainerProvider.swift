import SwiftData

public struct ModelContainerProvider {
    public enum StoreType {
        case persistent
        case inMemory
    }

    public static func makeContainer(storeType: StoreType = .persistent) throws -> ModelContainer {
        let schema = Schema(MovieTrackerSchemaV1.models)
        switch storeType {
        case .persistent:
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(
                for: schema,
                migrationPlan: MovieTrackerMigrationPlan.self,
                configurations: [configuration]
            )
        case .inMemory:
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }

    @MainActor
    public static func makeWatchlistEntryStore(container: ModelContainer) -> any EntityStore<WatchlistEntryEntity> {
        SwiftDataEntityStore<WatchlistEntryModel>(container: container)
    }

    @MainActor
    public static func makeReviewStore(container: ModelContainer) -> any EntityStore<ReviewEntity> {
        SwiftDataEntityStore<ReviewModel>(container: container)
    }
}

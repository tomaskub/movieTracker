import SwiftData

public struct ModelContainerProvider {
    public enum StoreType {
        case persistent
        case inMemory
    }

    public static func makeContainer(storeType: StoreType = .persistent) throws -> ModelContainer {
        let schema = Schema(MovieTrackerSchemaV1.models)
        let configuration: ModelConfiguration

        switch storeType {
        case .persistent:
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        case .inMemory:
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: MovieTrackerMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

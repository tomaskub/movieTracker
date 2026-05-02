import SwiftData

enum MovieTrackerSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [WatchlistEntryModel.self, ReviewModel.self]
    }
}

enum MovieTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [MovieTrackerSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

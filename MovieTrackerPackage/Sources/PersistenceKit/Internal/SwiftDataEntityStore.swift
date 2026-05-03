import SwiftData

@MainActor
final class SwiftDataEntityStore<Model: SwiftDataMappable>: EntityStore {
    typealias T = Model.Entity

    private let context: ModelContext

    init(container: ModelContainer) {
        self.context = container.mainContext
    }

    func insert(_ entity: T) throws {
        let existing = try allModels()
        guard !existing.contains(where: { $0.toEntity().id == entity.id }) else {
            throw PersistenceError.duplicateEntry
        }
        let model = Model.fromEntity(entity)
        context.insert(model)
        try save(wrapping: PersistenceError.insertFailed)
    }

    func update(_ entity: T) throws {
        let models = try allModels()
        guard let model = models.first(where: { $0.toEntity().id == entity.id }) else {
            throw PersistenceError.notFound
        }
        model.update(from: entity)
        try save(wrapping: PersistenceError.updateFailed)
    }

    func delete(_ entity: T) throws {
        let models = try allModels()
        guard let model = models.first(where: { $0.toEntity().id == entity.id }) else {
            throw PersistenceError.notFound
        }
        context.delete(model)
        try save(wrapping: PersistenceError.deleteFailed)
    }

    func fetch(_ query: EntityQuery<T>) throws -> [T] {
        let models = try allModels()
        var entities = models.map { $0.toEntity() }

        if let predicate = query.predicate {
            entities = try entities.filter { try predicate.evaluate($0) }
        }

        if !query.sortDescriptors.isEmpty {
            entities.sort(using: query.sortDescriptors)
        }

        if let limit = query.fetchLimit {
            entities = Array(entities.prefix(limit))
        }

        return entities
    }

    private func allModels() throws -> [Model] {
        do {
            return try context.fetch(FetchDescriptor<Model>())
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }

    private func save(wrapping makeError: (Error) -> PersistenceError) throws {
        do {
            try context.save()
        } catch {
            throw makeError(error)
        }
    }
}

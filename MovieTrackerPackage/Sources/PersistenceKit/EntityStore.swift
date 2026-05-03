public protocol EntityStore<T> where T: PersistableEntity {
    associatedtype T
    func insert(_ entity: T) throws
    func update(_ entity: T) throws
    func delete(_ entity: T) throws
    func fetch(_ query: EntityQuery<T>) throws -> [T]
}

import Foundation

public struct EntityQuery<T: PersistableEntity>: Sendable {
    public var predicate: Predicate<T>?
    public var sortDescriptors: [SortDescriptor<T>]
    public var fetchLimit: Int?

    public init(
        predicate: Predicate<T>? = nil,
        sortDescriptors: [SortDescriptor<T>] = [],
        fetchLimit: Int? = nil
    ) {
        self.predicate = predicate
        self.sortDescriptors = sortDescriptors
        self.fetchLimit = fetchLimit
    }
}

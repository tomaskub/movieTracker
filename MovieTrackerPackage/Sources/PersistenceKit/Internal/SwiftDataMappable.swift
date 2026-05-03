import SwiftData

protocol SwiftDataMappable: PersistentModel {
    associatedtype Entity: PersistableEntity
    func toEntity() -> Entity
    static func fromEntity(_ entity: Entity) -> Self
    func update(from entity: Entity)
}

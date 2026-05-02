import SwiftData

protocol SwiftDataMappable {
    associatedtype Entity
    func toEntity() -> Entity
    static func fromEntity(_ entity: Entity) -> Self
}

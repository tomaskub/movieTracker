import PersistenceKit

protocol ReviewStoring {
    func insert(_ entity: ReviewEntity) throws
    func update(_ entity: ReviewEntity) throws
    func fetch(movieId: Int) throws -> ReviewEntity?
    func delete(movieId: Int) throws
}

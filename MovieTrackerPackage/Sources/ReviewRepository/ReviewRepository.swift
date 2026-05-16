import DomainModels

public protocol ReviewRepository {
    func create(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws
    func update(movieId: Int, rating: Int, tags: [ReviewTag], notes: String) throws
    func fetch(movieId: Int) throws -> Review?
    func delete(movieId: Int) throws
    func contains(movieId: Int) throws -> Bool
}

public enum PersistenceError: Error {
    case insertFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case saveFailed(Error)
    case updateFailed(Error)
    case notFound
    case duplicateEntry
}

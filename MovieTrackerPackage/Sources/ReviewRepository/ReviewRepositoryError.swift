public enum ReviewRepositoryError: Error {
    case notFound
    case alreadyExists
    case invalidRating
    case fetchFailed(Error)
    case insertFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
}

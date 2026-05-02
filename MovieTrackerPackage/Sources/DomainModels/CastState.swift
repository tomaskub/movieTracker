public enum CastState: Equatable, Sendable {
    case notRetrieved
    case loaded([CastMember])
}

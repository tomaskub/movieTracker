public struct CastMember: Codable, Equatable, Sendable {
    public let name: String
    public let character: String

    public init(name: String, character: String) {
        self.name = name
        self.character = character
    }
}

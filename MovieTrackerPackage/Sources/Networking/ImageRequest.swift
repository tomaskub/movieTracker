public struct ImageRequest {
    public let path: String
    public let sizeVariant: String

    public init(path: String, sizeVariant: String) {
        self.path = path
        self.sizeVariant = sizeVariant
    }
}

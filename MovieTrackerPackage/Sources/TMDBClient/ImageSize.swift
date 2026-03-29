public enum ImageSize {
    case thumbnail
    case medium
    case original

    var sizeVariant: String {
        switch self {
        case .thumbnail: return "w185"
        case .medium: return "w500"
        case .original: return "original"
        }
    }
}

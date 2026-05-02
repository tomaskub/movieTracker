public enum ReviewTag: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case mustSee = "Must-see"
    case rewatchWorthy = "Rewatch-worthy"
    case underrated = "Underrated"
    case overrated = "Overrated"
    case comfortWatch = "Comfort watch"
    case dark = "Dark"
    case funny = "Funny"
    case emotional = "Emotional"
    case slowBurn = "Slow burn"
    case greatSoundtrack = "Great soundtrack"
    case thoughtProvoking = "Thought-provoking"
}

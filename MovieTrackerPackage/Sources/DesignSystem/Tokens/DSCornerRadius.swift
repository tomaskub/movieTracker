import CoreFoundation

public enum DSCornerRadius: CGFloat, CaseIterable, Sendable {
    /// Tags, chips, badges
    case small  = 6
    /// Movie card poster, input fields
    case medium = 10
    /// Cards, sheets
    case large  = 14
    /// Modal sheets, hero poster
    case xLarge = 20
    /// Pill buttons, rating badge
    case full   = 999
}

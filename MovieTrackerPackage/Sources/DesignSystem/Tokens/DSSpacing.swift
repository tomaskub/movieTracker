import CoreFoundation

public enum DSSpacing: CGFloat, CaseIterable, Sendable {
    case xxSmall  = 4
    case xSmall   = 8
    case small    = 12
    case medium   = 16
    case large    = 24
    case xLarge   = 32
    case xxLarge  = 48
    case xxxLarge = 64
}

// MARK: - CGFloat convenience

public extension CGFloat {
    static let dsXXSmall: CGFloat  = 4
    static let dsXSmall: CGFloat   = 8
    static let dsSmall: CGFloat    = 12
    static let dsMedium: CGFloat   = 16
    static let dsLarge: CGFloat    = 24
    static let dsXLarge: CGFloat   = 32
    static let dsXXLarge: CGFloat  = 48
    static let dsXXXLarge: CGFloat = 64
}

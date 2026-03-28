import SwiftUI

public extension Color {

    // MARK: - Background

    static var backgroundPrimary: Color   { DSColors.backgroundPrimary }
    static var backgroundSecondary: Color { DSColors.backgroundSecondary }
    static var backgroundTertiary: Color  { DSColors.backgroundTertiary }
    static var backgroundOverlay: Color   { DSColors.backgroundOverlay }

    // MARK: - Label / Text

    static var labelOnDark: Color { DSColors.labelOnDark }

    // MARK: - Interactive

    static var accent: Color       { DSColors.accent }
    static var accentSubtle: Color { DSColors.accentSubtle }

    // MARK: - Rating

    static var rating: Color { DSColors.rating }

    // MARK: - Semantic State

    static var error: Color       { DSColors.error }
    static var errorSubtle: Color { DSColors.errorSubtle }
    static var success: Color     { DSColors.success }

    // MARK: - Separator

    static var separator: Color { DSColors.separator }
}

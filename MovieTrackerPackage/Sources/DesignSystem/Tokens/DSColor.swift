import SwiftUI
import UIKit

// MARK: - Brand Palette

/// Raw brand colors extracted from the design palette.
/// Prefer semantic tokens below for all UI code.
public extension Color {
    /// `#0d1b2a` — primary dark navy; nav bars, card surfaces, poster placeholders
    static let dsPrimary = Color(hex: "#0d1b2a")
    /// `#1b263b` — secondary dark blue; secondary surfaces and grouped backgrounds
    static let dsSecondary = Color(hex: "#1b263b")
    /// `#e63946` — accent red; primary CTAs, active states, error indicators
    static let dsAccent = Color(hex: "#e63946")
    /// `#f77f00` — gold orange; star ratings, film icon tint
    static let dsGold = Color(hex: "#f77f00")
}

// MARK: - Semantic Tokens

public struct DSColors: Sendable {
    private init() {}

    // MARK: - Background
    public static let backgroundPrimary = Color(UIColor.systemBackground)
    public static let backgroundSecondary = Color(hex: "#0d1b2a")
    public static let backgroundTertiary = Color(hex: "#1b263b")
    public static let backgroundOverlay = Color.black.opacity(0.4)

    // MARK: - Label / Text
    public static let labelPrimary = Color(UIColor.label)
    public static let labelSecondary = Color(UIColor.secondaryLabel)
    public static let labelTertiary = Color(UIColor.tertiaryLabel)
    /// White — for text drawn on top of dark navy surfaces
    public static let labelOnDark = Color.white

    // MARK: - Interactive
    public static let accent = Color(hex: "#e63946")
    public static let accentSubtle = Color(hex: "#e63946").opacity(0.15)

    // MARK: - Semantic State
    /// Shares the accent red per design — no separate error color in this palette
    public static let error = Color(hex: "#e63946")
    public static let errorSubtle = Color(hex: "#e63946").opacity(0.12)
    public static let success = Color(UIColor.systemGreen)

    // MARK: - Rating
    public static let rating = Color(hex: "#f77f00")

    // MARK: - Separator
    public static let separator = Color(UIColor.separator)
}

import SwiftUI

/// Typography scale matching the design mockup.
///
/// Primary scale (shown in the "Typography Scale" spec):
/// `heading1` → `heading2` → `heading3` → `body` → `small` → `caption`
///
/// Supporting scale for UI controls not shown in the spec:
/// `buttonLabel`, `tagLabel`
public struct DSFonts: Sendable {
    private init() {}

    // MARK: - Primary Scale

    /// Largest display text — screen heroes, modal titles. ~34pt black.
    public static let heading1: Font = .system(size: 34, weight: .black, design: .default)

    /// Section or card heading. ~24pt bold.
    public static let heading2: Font = .system(size: 24, weight: .bold, design: .default)

    /// Sub-section heading, list item title. ~20pt semibold.
    public static let heading3: Font = .system(size: 20, weight: .semibold, design: .default)

    /// Primary body copy — overviews, notes, descriptions. ~16pt regular.
    public static let body: Font = .system(size: 16, weight: .regular, design: .default)

    /// Secondary body copy — metadata, cast roles, timestamps. ~13pt regular.
    public static let small: Font = .system(size: 13, weight: .regular, design: .default)

    /// Footnote-level text — release year on cards, legal. ~11pt regular.
    public static let caption: Font = .system(size: 11, weight: .regular, design: .default)

    // MARK: - Supporting Scale

    /// Primary and secondary button labels. ~15pt semibold.
    public static let buttonLabel: Font = .system(size: 15, weight: .semibold, design: .default)

    /// Genre tags, review tags, badges. ~12pt medium.
    public static let tagLabel: Font = .system(size: 12, weight: .medium, design: .default)
}

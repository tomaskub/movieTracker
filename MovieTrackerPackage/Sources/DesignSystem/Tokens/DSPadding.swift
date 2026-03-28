import SwiftUI

/// Semantic insets that answer "how much padding does this context need"
/// rather than exposing raw spacing numbers directly.
public enum DSPadding: Sendable {
    /// Outer horizontal margin for all full-width content (16 pt)
    case screenEdge
    /// Inner padding inside MovieCard, ReviewSummaryView (12 pt)
    case cardContent
    /// Top/bottom breathing room between sections (24 pt)
    case sectionVertical
    /// Gap between a label and its associated control within a component (8 pt)
    case componentGap
    /// Inner padding on chip/tag pills — asymmetric (6 h × 4 v)
    case tagInset
    /// Content inset inside each wizard step (20 pt)
    case wizardStep
    /// Padding inside bottom sheets and the filter sheet (24 pt)
    case sheetContent
    /// Minimum tappable target size per HIG (44 pt)
    case iconHitArea

    /// Uniform inset value. For asymmetric cases (`tagInset`) returns the horizontal value.
    public var value: CGFloat {
        switch self {
        case .screenEdge:      return 16
        case .cardContent:     return 12
        case .sectionVertical: return 24
        case .componentGap:    return 8
        case .tagInset:        return 6
        case .wizardStep:      return 20
        case .sheetContent:    return 24
        case .iconHitArea:     return 44
        }
    }

    /// Full `EdgeInsets` for use with `.padding(_ insets:)`.
    public var edgeInsets: EdgeInsets {
        switch self {
        case .screenEdge:
            return EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        case .cardContent:
            return EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        case .sectionVertical:
            return EdgeInsets(top: 24, leading: 0, bottom: 24, trailing: 0)
        case .componentGap:
            return EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        case .tagInset:
            return EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        case .wizardStep:
            return EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        case .sheetContent:
            return EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
        case .iconHitArea:
            return EdgeInsets(top: 44, leading: 44, bottom: 44, trailing: 44)
        }
    }
}

import SwiftUI

public extension VStack {
    init(
        alignment: HorizontalAlignment = .center,
        spacing: DSSpacing,
        @ViewBuilder content: () -> Content
    ) {
        self.init(alignment: alignment, spacing: spacing.rawValue, content: content)
    }
}

public extension HStack {
    init(
        alignment: VerticalAlignment = .center,
        spacing: DSSpacing,
        @ViewBuilder content: () -> Content
    ) {
        self.init(alignment: alignment, spacing: spacing.rawValue, content: content)
    }
}

public extension LazyVStack {
    init(
        alignment: HorizontalAlignment = .center,
        spacing: DSSpacing,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: () -> Content
    ) {
        self.init(alignment: alignment, spacing: spacing.rawValue, pinnedViews: pinnedViews, content: content)
    }
}

public extension LazyHStack {
    init(
        alignment: VerticalAlignment = .center,
        spacing: DSSpacing,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: () -> Content
    ) {
        self.init(alignment: alignment, spacing: spacing.rawValue, pinnedViews: pinnedViews, content: content)
    }
}

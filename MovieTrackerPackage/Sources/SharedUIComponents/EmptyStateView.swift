import SwiftUI
import DesignSystem

public struct EmptyStateView: View {

    private let title: String
    private let subtitle: String?

    public init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: .small) {
            Text(title)
                .font(.heading3)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.dsBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.sectionVertical)
        .padding(.horizontal, .screenEdge)
    }
}

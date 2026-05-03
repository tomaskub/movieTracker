import SwiftUI
import DesignSystem

public struct ErrorStateView: View {

    private let message: String
    private let onRetry: () -> Void

    public init(message: String, onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: .small) {
            Image.errorCircle
                .font(.system(size: 36))
                .foregroundStyle(Color.error)

            Text(message)
                .font(.dsBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                HStack(spacing: 6) {
                    Image.retry
                    Text("Retry")
                }
                .font(.buttonLabel)
                .foregroundStyle(Color.accent)
            }
        }
        .padding(.sectionVertical)
        .padding(.horizontal, .screenEdge)
    }
}

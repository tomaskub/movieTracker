import SwiftUI
import DesignSystem

public struct InlineErrorView: View {

    private let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image.errorCircle
                .font(.dsCaption)
                .foregroundStyle(Color.error)

            Text(message)
                .font(.dsCaption)
                .foregroundStyle(Color.error)
        }
    }
}

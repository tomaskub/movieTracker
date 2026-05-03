import SwiftUI
import DesignSystem

public struct LoadingView: View {

    public init() {}

    public var body: some View {
        ProgressView()
            .tint(.accent)
            .padding(.sectionVertical)
    }
}

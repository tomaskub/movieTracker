import SwiftUI
import DesignSystem

public struct MovieCardView: View {

    public enum ImageState {
        case placeholder
        case image(Image)
    }

    private let title: String
    private let year: Int
    private let rating: Double
    private let imageState: ImageState

    public init(title: String, year: Int, rating: Double, imageState: ImageState) {
        self.title = title
        self.year = year
        self.rating = rating
        self.imageState = imageState
    }

    public var body: some View {
        HStack(spacing: .small) {
            posterImage
                .frame(width: 80, height: 120)
                .cornerRadius(.medium)
                .shadow(.card)

            VStack(alignment: .leading, spacing: .xSmall) {
                Text(title)
                    .font(.heading3)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(String(year))
                    .font(.dsBody)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image.starFilled
                        .font(.dsCaption)
                        .foregroundStyle(Color.rating)
                    Text(formatRating(rating))
                        .font(.dsCaption)
                        .foregroundStyle(Color.rating)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.cardContent)
    }

    @ViewBuilder
    private var posterImage: some View {
        switch imageState {
        case .placeholder:
            Rectangle()
                .fill(Color.backgroundSecondary)
                .overlay(
                    Image.film
                        .font(.system(size: 28))
                        .foregroundStyle(Color.labelOnDark)
                )
        case .image(let image):
            image
                .resizable()
                .scaledToFill()
                .clipped()
        }
    }
}

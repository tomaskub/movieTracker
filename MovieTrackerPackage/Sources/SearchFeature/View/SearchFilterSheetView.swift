import DesignSystem
import DomainModels
import SharedUIComponents
import SwiftUI

struct SearchFilterSheetView: View {
    private let presenter: SearchFilterSheetPresenter
    @Environment(\.dismiss) private var dismiss

    init(presenter: SearchFilterSheetPresenter) {
        self.presenter = presenter
    }

    var body: some View {
        NavigationStack {
            Form {
                genreSection
                ratingSection
                yearSection
                clearSection
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presenter.confirm()
                        dismiss()
                    }
                }
            }
            .onAppear { presenter.viewAppeared() }
        }
    }

    @ViewBuilder
    private var genreSection: some View {
        Section("Genres") {
            switch presenter.genreLoadState {
            case .loading:
                LoadingView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            case .loaded(let genres):
                ForEach(genres) { genre in
                    Button {
                        presenter.toggleGenre(id: genre.id)
                    } label: {
                        HStack {
                            Text(genre.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if presenter.draftFilters.selectedGenreIds.contains(genre.id) {
                                Image.checkmark
                                    .foregroundStyle(Color.accent)
                            }
                        }
                    }
                }
            case .error:
                HStack(spacing: .xSmall) {
                    InlineErrorView(message: "Failed to load genres.")
                    Spacer()
                    Button("Retry") { presenter.retryGenreFetch() }
                        .font(.buttonLabel)
                        .foregroundStyle(Color.accent)
                }
            }
        }
    }

    @ViewBuilder
    private var ratingSection: some View {
        Section("Minimum Rating") {
            Toggle("Enable minimum rating", isOn: Binding(
                get: { presenter.draftFilters.minimumRatingEnabled },
                set: { _ in presenter.toggleMinimumRating() }
            ))

            if presenter.draftFilters.minimumRatingEnabled {
                Stepper(
                    "Rating: \(presenter.draftFilters.minimumRating)/10",
                    value: Binding(
                        get: { presenter.draftFilters.minimumRating },
                        set: { presenter.setMinimumRating($0) }
                    ),
                    in: 1...10
                )
            }
        }
    }

    @ViewBuilder
    private var yearSection: some View {
        Section("Release Year") {
            VStack(alignment: .leading, spacing: .xSmall) {
                TextField("From year", text: Binding(
                    get: { presenter.draftFilters.fromYear },
                    set: { presenter.updateFromYear($0) }
                ))
                .keyboardType(.numberPad)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            presenter.fromYearError != nil ? Color.error : Color.clear,
                            lineWidth: 1.5
                        )
                )

                if let error = presenter.fromYearError, !error.isEmpty {
                    Text(error)
                        .font(.dsCaption)
                        .foregroundStyle(Color.error)
                }
            }

            VStack(alignment: .leading, spacing: .xSmall) {
                TextField("To year", text: Binding(
                    get: { presenter.draftFilters.toYear },
                    set: { presenter.updateToYear($0) }
                ))
                .keyboardType(.numberPad)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            presenter.toYearError != nil ? Color.error : Color.clear,
                            lineWidth: 1.5
                        )
                )

                if let error = presenter.toYearError, !error.isEmpty {
                    Text(error)
                        .font(.dsCaption)
                        .foregroundStyle(Color.error)
                }
            }

            if let rangeError = presenter.yearRangeError {
                Text(rangeError)
                    .font(.dsCaption)
                    .foregroundStyle(Color.error)
            }
        }
    }

    @ViewBuilder
    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                presenter.clearAllFilters()
            } label: {
                Text("Clear All Filters")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

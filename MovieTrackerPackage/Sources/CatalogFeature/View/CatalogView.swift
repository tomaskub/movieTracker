import MovieDetailFeature
import SharedUIComponents
import SwiftUI
import TMDBClient

struct CatalogView: View {
    private let presenter: CatalogPresenter
    @Bindable private var router: CatalogRouter

    init(presenter: CatalogPresenter, router: CatalogRouter) {
        self.presenter = presenter
        _router = Bindable(router)
    }

    var body: some View {
        NavigationStack(path: $router.navigationPath) {
            content
                .navigationTitle("Trending")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: Int.self) { movieId in
                    router.movieDetailRouter.makeView(movieId: movieId)
                }
        }
        .onAppear { presenter.handleAppear() }
    }

    @ViewBuilder
    private var content: some View {
        switch presenter.phase {
        case .idle:
            Color.clear
        case .loading:
            List {
                LoadingView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                ForEach(0..<5, id: \.self) { _ in
                    MovieCardView(title: "", year: 0, rating: 0, imageState: .placeholder)
                }
            }
            .listStyle(.plain)
            .redacted(reason: .placeholder)
        case .loaded(let rows):
            List(rows) { row in
                Button {
                    presenter.handleMovieTap(movieId: row.id)
                } label: {
                    MovieCardView(
                        title: row.title,
                        year: row.year,
                        rating: row.voteAverage,
                        imageState: presenter.imageStates[row.id] ?? .placeholder
                    )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        case .failed:
            VStack {
                ErrorStateView(
                    message: "Something went wrong. Please try again.",
                    onRetry: presenter.handleRetry
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

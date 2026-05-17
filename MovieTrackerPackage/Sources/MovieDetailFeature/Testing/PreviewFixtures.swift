#if DEBUG
import DomainModels
import Foundation

enum PreviewFixtures {
    static let movie = Movie(
        id: 550,
        title: "Fight Club",
        overview: "A ticking-time-bomb insomniac and a slippery soap salesman channel primal male aggression into a shocking new form of therapy. Their concept catches on, with underground fight clubs forming in every town, until an eccentric gets in the way and raises the stakes.",
        releaseDate: "1999-10-15",
        genreIds: [18, 53],
        posterPath: "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
        voteAverage: 8.4
    )

    static let genres = [
        Genre(id: 18, name: "Drama"),
        Genre(id: 53, name: "Thriller"),
    ]

    static let movieDetail = MovieDetail(
        movie: movie,
        genres: genres,
        cast: .notRetrieved
    )

    static let castMembers: [CastMember] = [
        CastMember(name: "Brad Pitt", character: "Tyler Durden"),
        CastMember(name: "Edward Norton", character: "The Narrator"),
        CastMember(name: "Helena Bonham Carter", character: "Marla Singer"),
        CastMember(name: "Meat Loaf", character: "Robert Paulson"),
    ]

    static let review = Review(
        movieId: 550,
        rating: 4,
        tags: [.mustSee, .thoughtProvoking],
        notes: "A masterpiece of modern cinema. The twist is unforgettable.",
        createdAt: Date(),
        updatedAt: Date()
    )
}
#endif

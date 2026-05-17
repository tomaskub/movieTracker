#if DEBUG
import DomainModels

enum SearchFixtures {
    static let movies: [Movie] = [
        Movie(
            id: 101,
            title: "Inception",
            overview: "A thief who steals corporate secrets through dream-sharing technology.",
            releaseDate: "2010-07-16",
            genreIds: [28, 878],
            posterPath: "/inception.jpg",
            voteAverage: 8.8
        ),
        Movie(
            id: 102,
            title: "Arrival",
            overview: "A linguist works with the military to communicate with alien lifeforms.",
            releaseDate: "2016-11-11",
            genreIds: [18, 878],
            posterPath: "/arrival.jpg",
            voteAverage: 7.9
        ),
        Movie(
            id: 103,
            title: "Blade Runner 2049",
            overview: "A young blade runner discovers a long-buried secret.",
            releaseDate: "2017-10-06",
            genreIds: [878, 18],
            posterPath: nil,
            voteAverage: 7.6
        ),
        Movie(
            id: 104,
            title: "Her",
            overview: "A man falls in love with an AI operating system.",
            releaseDate: "2013-12-18",
            genreIds: [18, 10749],
            posterPath: "/her.jpg",
            voteAverage: 8.0
        ),
        Movie(
            id: 105,
            title: "Everything Everywhere All at Once",
            overview: "An aging Chinese immigrant is swept up in an adventure.",
            releaseDate: "2022-03-25",
            genreIds: [28, 35, 878],
            posterPath: "/eeaao.jpg",
            voteAverage: 7.8
        ),
    ]

    static let genres: [Genre] = [
        Genre(id: 28, name: "Action"),
        Genre(id: 18, name: "Drama"),
        Genre(id: 35, name: "Comedy"),
        Genre(id: 878, name: "Science Fiction"),
        Genre(id: 10749, name: "Romance"),
        Genre(id: 27, name: "Horror"),
        Genre(id: 12, name: "Adventure"),
        Genre(id: 80, name: "Crime"),
    ]
}
#endif

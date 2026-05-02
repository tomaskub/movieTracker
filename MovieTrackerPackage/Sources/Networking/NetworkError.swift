import Foundation

public enum NetworkError: Error {
    case invalidURL
    case noConnectivity
    case serverError(statusCode: Int)
    case decodingError(DecodingError)
    case transportError(URLError)
}

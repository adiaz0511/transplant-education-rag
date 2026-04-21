import Foundation

enum APIError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case invalidUTF8Stream
    case secureConnectionFailed
    case serverBusy
    case configurationError(String)
    case requestSigningFailed(String)
    case httpError(statusCode: Int, message: String?)
    case transportError(url: String, message: String, requestBody: String?, underlying: String?)
    case responseParsingFailed(message: String, responseText: String)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is invalid."
        case .invalidResponse:
            return "The server response was invalid."
        case .invalidUTF8Stream:
            return "The server response contained invalid UTF-8."
        case .secureConnectionFailed:
            return "Secure connection failed. Please try again."
        case .serverBusy:
            return "The server is busy right now. Please try again."
        case let .configurationError(message), let .requestSigningFailed(message):
            return message
        case let .httpError(statusCode, message):
            if let message, !message.isEmpty {
                return "Request failed (\(statusCode)): \(message)"
            }

            return "Request failed with status code \(statusCode)."
        case let .transportError(_, message, _, _):
            return message
        case let .responseParsingFailed(message, _):
            return message
        case let .decodingFailed(error):
            return "Failed to decode the server response: \(error.localizedDescription)"
        }
    }

    var failureDetails: String? {
        switch self {
        case let .transportError(url, _, requestBody, underlying):
            var lines = [
                "Request URL: \(url)",
                "No response body was available because the transport failed before URLSession produced a valid HTTP response."
            ]
            if let requestBody, !requestBody.isEmpty {
                lines.append("Request Body:")
                lines.append(requestBody)
            }
            if let underlying, !underlying.isEmpty {
                lines.append("Underlying: \(underlying)")
            }
            return lines.joined(separator: "\n")
        case let .responseParsingFailed(_, responseText):
            return responseText
        case let .httpError(_, message):
            return message
        case .invalidURL,
             .invalidResponse,
             .invalidUTF8Stream,
             .secureConnectionFailed,
             .serverBusy,
             .configurationError,
             .requestSigningFailed,
             .decodingFailed:
            return nil
        }
    }
}

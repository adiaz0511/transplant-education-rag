import Foundation

struct StreamResponseParts {
    let jsonData: Data?
}

enum StreamResponseParser {
    static func split(_ response: String) -> StreamResponseParts {
        let jsonString = sanitizeJSONString(
            normalizeJSONString(
            response.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )

        let jsonData = jsonString.isEmpty ? nil : jsonString.data(using: .utf8)

        return StreamResponseParts(jsonData: jsonData)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data?) throws -> T? {
        guard let data else {
            return nil
        }

        return try JSONDecoder().decode(type, from: data)
    }

    private static func normalizeJSONString(_ jsonString: String) -> String {
        guard jsonString.hasPrefix("```") else {
            return jsonString
        }

        var lines = jsonString.components(separatedBy: .newlines)
        guard !lines.isEmpty else {
            return jsonString
        }

        lines.removeFirst()

        if let lastLine = lines.last, lastLine.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
            lines.removeLast()
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sanitizeJSONString(_ jsonString: String) -> String {
        guard !jsonString.isEmpty else {
            return jsonString
        }

        var sanitized = ""
        sanitized.reserveCapacity(jsonString.count)

        var isInsideString = false
        var isEscaping = false

        for character in jsonString {
            if isInsideString {
                if isEscaping {
                    sanitized.append(character)
                    isEscaping = false
                    continue
                }

                switch character {
                case "\\":
                    sanitized.append(character)
                    isEscaping = true
                case "\"":
                    sanitized.append(character)
                    isInsideString = false
                case "\n":
                    sanitized.append("\\n")
                case "\r":
                    sanitized.append("\\r")
                case "\t":
                    sanitized.append("\\t")
                default:
                    sanitized.append(character)
                }
            } else {
                sanitized.append(character)

                if character == "\"" {
                    isInsideString = true
                }
            }
        }

        return sanitized
    }
}

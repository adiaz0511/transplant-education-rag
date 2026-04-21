import Foundation

struct AskResponse: Decodable {
    let data: AskData?
    let sources: [String]?

    private enum CodingKeys: String, CodingKey {
        case data
        case sources
    }

    init(data: AskData?, sources: [String]?) {
        self.data = data
        self.sources = sources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.data) {
            data = try container.decodeIfPresent(AskData.self, forKey: .data)
            sources = try container.decodeIfPresent([String].self, forKey: .sources)
            return
        }

        data = try AskData(from: decoder)
        sources = try container.decodeIfPresent([String].self, forKey: .sources)
    }
}

struct AskData: Decodable {
    let answer: String?
    let keyPoints: [String]?
    let sourceIndices: [Int]?

    enum CodingKeys: String, CodingKey {
        case answer
        case keyPoints = "key_points"
        case sourceIndices = "source_indices"
    }
}

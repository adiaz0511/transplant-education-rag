import Foundation

struct QuizResponse: Decodable {
    let data: QuizData?
    let sources: [String]?

    private enum CodingKeys: String, CodingKey {
        case data
        case sources
    }

    init(data: QuizData?, sources: [String]?) {
        self.data = data
        self.sources = sources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.data) {
            data = try container.decodeIfPresent(QuizData.self, forKey: .data)
            sources = try container.decodeIfPresent([String].self, forKey: .sources)
            return
        }

        data = try QuizData(from: decoder)
        sources = try container.decodeIfPresent([String].self, forKey: .sources)
    }
}

struct QuizData: Decodable {
    let questions: [QuizQuestion]?
    let sourceIndices: [Int]?

    enum CodingKeys: String, CodingKey {
        case questions
        case sourceIndices = "source_indices"
    }
}

struct QuizQuestion: Decodable {
    let question: String?
    let type: String?
    let options: [String]?
    let answer: String?
    let explanation: String?
}

import Foundation

struct LessonResponse: Decodable {
    let data: LessonData?
    let sources: [String]?

    private enum CodingKeys: String, CodingKey {
        case data
        case sources
    }

    init(data: LessonData?, sources: [String]?) {
        self.data = data
        self.sources = sources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.data) {
            data = try container.decodeIfPresent(LessonData.self, forKey: .data)
            sources = try container.decodeIfPresent([String].self, forKey: .sources)
            return
        }

        data = try LessonData(from: decoder)
        sources = try container.decodeIfPresent([String].self, forKey: .sources)
    }
}

struct LessonData: Decodable {
    let title: String?
    let lessonMarkdown: String?
    let keyTakeaways: [String]?
    let sourceIndices: [Int]?

    enum CodingKeys: String, CodingKey {
        case title
        case lessonMarkdown = "lesson_markdown"
        case keyTakeaways = "key_takeaways"
        case sourceIndices = "source_indices"
    }
}

import Foundation
import SwiftData

@Model
final class Lesson {
    @Attribute(.unique) var id: UUID
    var topicId: UUID
    var title: String
    var content: String
    var keyTakeawaysPayload: String
    var sourcesPayload: String
    var createdAt: Date

    var keyTakeaways: [String] {
        get { Self.decodeStringArray(from: keyTakeawaysPayload) }
        set { keyTakeawaysPayload = Self.encodeStringArray(newValue) }
    }

    var sources: [String] {
        get { Self.decodeStringArray(from: sourcesPayload) }
        set { sourcesPayload = Self.encodeStringArray(newValue) }
    }

    init(
        id: UUID = UUID(),
        topicId: UUID,
        title: String,
        content: String,
        keyTakeaways: [String] = [],
        sources: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.topicId = topicId
        self.title = title
        self.content = content
        self.keyTakeawaysPayload = Self.encodeStringArray(keyTakeaways)
        self.sourcesPayload = Self.encodeStringArray(sources)
        self.createdAt = createdAt
    }

    private static func encodeStringArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private static func decodeStringArray(from payload: String) -> [String] {
        guard let data = payload.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return values
    }
}

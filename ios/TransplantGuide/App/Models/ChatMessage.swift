import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var threadID: UUID
    var roleRawValue: String
    var content: String
    var keyPointsPayload: String
    var sourceIndicesPayload: String
    var sourcesPayload: String
    var createdAt: Date
    var thread: ChatThread?

    var role: ChatRole {
        get { ChatRole(rawValue: roleRawValue) ?? .assistant }
        set { roleRawValue = newValue.rawValue }
    }

    var keyPoints: [String] {
        get { Self.decodeStrings(from: keyPointsPayload) }
        set { keyPointsPayload = Self.encodeStrings(newValue) }
    }

    var sourceIndices: [Int] {
        get { Self.decodeInts(from: sourceIndicesPayload) }
        set { sourceIndicesPayload = Self.encodeInts(newValue) }
    }

    var sources: [String] {
        get { Self.decodeStrings(from: sourcesPayload) }
        set { sourcesPayload = Self.encodeStrings(newValue) }
    }

    init(
        id: UUID = UUID(),
        thread: ChatThread,
        role: ChatRole,
        content: String,
        keyPoints: [String] = [],
        sourceIndices: [Int] = [],
        sources: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.threadID = thread.id
        self.roleRawValue = role.rawValue
        self.content = content
        self.keyPointsPayload = Self.encodeStrings(keyPoints)
        self.sourceIndicesPayload = Self.encodeInts(sourceIndices)
        self.sourcesPayload = Self.encodeStrings(sources)
        self.createdAt = createdAt
        self.thread = thread
    }

    private static func encodeStrings(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private static func decodeStrings(from payload: String) -> [String] {
        guard let data = payload.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return values
    }

    private static func encodeInts(_ values: [Int]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private static func decodeInts(from payload: String) -> [Int] {
        guard let data = payload.data(using: .utf8),
              let values = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }

        return values
    }
}

enum ChatRole: String {
    case user
    case assistant
}

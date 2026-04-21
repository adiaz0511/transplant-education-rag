import Foundation
import SwiftData

@Model
final class ChatThread {
    @Attribute(.unique) var id: UUID
    var title: String
    var conversationSummary: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.thread)
    var messages: [ChatMessage]

    init(
        id: UUID = UUID(),
        title: String = "New chat",
        conversationSummary: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.title = title
        self.conversationSummary = conversationSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

import Foundation

enum TopicStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case generating
    case failed
    case completed

    var id: String { rawValue }
}

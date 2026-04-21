import Foundation
import SwiftData

@Model
final class Topic {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var slug: String
    var title: String
    var order: Int
    private var statusRawValue: String
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        slug: String,
        title: String,
        order: Int,
        status: TopicStatus = .pending,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.slug = slug
        self.title = title
        self.order = order
        self.statusRawValue = status.rawValue
        self.errorMessage = errorMessage
    }

    var status: TopicStatus {
        get { TopicStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }
}

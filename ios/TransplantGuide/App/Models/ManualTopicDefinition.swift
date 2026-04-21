import Foundation

struct ManualTopicDefinition: Identifiable, Hashable {
    let slug: String
    let title: String
    let detail: String

    var id: String { slug }
}

import Foundation

struct QuizCitationSheetItem: Identifiable {
    let sourceIndex: Int
    let sourceText: String

    var id: Int { sourceIndex }
    var displayIndex: Int { sourceIndex + 1 }
}

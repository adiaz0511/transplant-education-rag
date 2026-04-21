import Foundation

struct AskSourceSheetItem: Identifiable {
    let sourceIndex: Int
    let sourceText: String

    var id: String { "\(sourceIndex)-\(sourceText.prefix(24))" }
    var label: String { "[\(sourceIndex)]" }
}

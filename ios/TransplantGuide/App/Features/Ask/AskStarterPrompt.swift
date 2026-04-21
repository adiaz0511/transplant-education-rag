import Foundation

struct AskStarterPrompt: Identifiable {
    let id = UUID()
    let title: String

    static let defaultPrompts: [AskStarterPrompt] = [
        AskStarterPrompt(title: "What symptoms mean I should call the transplant team?"),
        AskStarterPrompt(title: "How should we prepare for clinic appointments after discharge?"),
        AskStarterPrompt(title: "What do anti-rejection medicines do, and what should we watch for?"),
        AskStarterPrompt(title: "What are the warning signs of infection after transplant?"),
        AskStarterPrompt(title: "How often will labs and follow-up visits happen early on?"),
        AskStarterPrompt(title: "What should we do if my child misses a medicine dose?"),
        AskStarterPrompt(title: "How can we lower infection risk at home and in public?"),
        AskStarterPrompt(title: "Which vital signs should we watch closely after discharge?")
    ]
}

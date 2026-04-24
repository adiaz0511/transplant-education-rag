import Foundation

enum GenerationInstructions {
    static func lessonInstructions(for topic: String) -> String {
        """
        Topic focus: "\(topic)"

        Lesson formatting preferences:
        - Write for pediatric heart transplant caregivers and families.
        - Keep the tone warm, clear, reassuring, and non-clinical.
        - Prefer short sections, bullets, and scannable explanations in `lesson_markdown`.
        - Keep the response concise and practical, around 5 short sections maximum.
        - Emphasize what matters, why it matters, and what the caregiver should do.
        - Include practical actions and warning signs when relevant.
        - Avoid repeating the same advice in multiple sections.
        - Do not mention quizzes, app navigation, prompts, or implementation details.
        """
    }

    static func quizInstructions(for lessonTitle: String) -> String {
        """
        Lesson focus: "\(lessonTitle)"

        Quiz generation preferences:
        - Generate exactly 5 questions.
        - Prefer multiple-choice questions with 4 options when possible.
        - Make distractors plausible but clearly incorrect.
        - Keep wording simple, direct, and caregiver-friendly.
        - Keep explanations short, ideally 1 sentence each.
        - Favor practical understanding, warning signs, daily care steps, and safety decisions when applicable.
        - Do not mention app behavior, scoring, prompts, or implementation details in the question text.
        """
    }
}

from app.config import MAX_INSTRUCTIONS_CHARS


def build_prompt(input_text, context_chunks, task, instructions: str | None = None):
    indexed_context = "\n".join(
        [f"[{i}] {chunk}" for i, chunk in enumerate(context_chunks)]
    )

    if task == "qa":
        instruction = "Answer the question using only the provided context."
        style_block = """
QA STYLE:
- Keep the answer concise and easy to scan.
- Use short paragraphs or a short bullet list when helpful.
- If you use bullets, add citations at the end of each bullet.
""".strip()
        schema = """
{
  "answer": "string (markdown formatted)",
  "key_points": ["string", "string"],
  "source_indices": [0, 1],
  "sources": ["string", "string"]
}
""".strip()

    elif task == "lesson":
        instruction = "Create a clear lesson for a parent based only on the provided context."
        style_block = """
LESSON STYLE:
- Write polished, reader-friendly markdown instead of one dense paragraph.
- Start with a short introductory sentence or short opening paragraph.
- Then use 2 to 4 short sections with markdown headings like `## What to expect` or `## What to do`.
- Under each section, use short bullet lists.
- Keep each bullet to 1 or 2 sentences.
- Put citation markers at the end of each bullet or paragraph, not in the middle of a sentence unless necessary.
- Prefer bullets over long paragraphs.
- Do not repeat the title inside `lesson_markdown`.
""".strip()
        schema = """
{
  "title": "string",
  "lesson_markdown": "string (well-structured markdown with inline citations like [0] or [1][2])",
  "key_takeaways": ["string", "string"],
  "source_indices": [0, 1],
  "sources": ["string", "string"]
}
""".strip()

    elif task == "quiz":
        instruction = "Create a short quiz based only on the provided context."
        style_block = """
QUIZ STYLE:
- Keep each question short and clear.
- Keep answer choices concise.
- Write explanations in 1 short paragraph or 1 short bullet.
- Put citation markers at the end of each explanation.
""".strip()
        schema = """
{
  "questions": [
    {
      "question": "string",
      "type": "multiple_choice | true_false",
      "options": ["string", "string"],
      "answer": "string",
      "explanation": "string with inline citations like [0] or [1][2]"
    }
  ],
  "source_indices": [0, 1],
  "sources": ["string", "string"]
}
""".strip()

    else:
        raise ValueError(f"Unsupported task: {task}")

    instructions_block = ""
    if instructions:
        instructions = instructions.strip()
        if len(instructions) > MAX_INSTRUCTIONS_CHARS:
            instructions = instructions[:MAX_INSTRUCTIONS_CHARS].rstrip()
        instructions_block = f"""
Additional formatting preferences:
{instructions}
""".strip()

    return f"""
You are a medical assistant helping parents understand a transplant care manual.

OUTPUT FORMAT:

Return ONLY a valid JSON object.
Do NOT include any text before or after the JSON.
Do NOT wrap the JSON in code blocks.

MARKDOWN USAGE:
- Markdown is allowed ONLY inside the designated fields:
  - qa: "answer"
  - lesson: "lesson_markdown"
- Do NOT include markdown anywhere else in the JSON.

CITATIONS:
- Use inline citation markers based on the provided chunk indices.
- Citation format must be exactly [0], [1], [2], or combined like [0][2].
- Only cite chunk indices that exist in the provided context.
- For lesson output, every bullet or paragraph in "lesson_markdown" must include at least one citation marker.
- For quiz output, every question "explanation" must include at least one citation marker.
- The "source_indices" field MUST match the citation markers actually used in the content.
- The "sources" field MUST contain the exact raw text for those cited chunk indices.

RULES:
- Use ONLY the provided context
- Do NOT add external knowledge
- Only include source indices that directly support the answer
- The "sources" field MUST contain the exact raw text of the referenced chunks (matching source_indices)
- The JSON must be valid and complete
- The JSON section must NOT be wrapped in backticks or code blocks
- Do NOT include anything after the JSON
- Return JSON that satisfies all of these rules

MARKDOWN COMPATIBILITY RULES (applies ONLY to markdown fields):

- Use clean CommonMark supported by the Textual library
- DO NOT use HTML (no <a>, no tel:, no inline HTML of any kind)

LINKS AND PHONE NUMBERS:
- URLs must use markdown: [MyChart](https://mychart)
- Phone numbers must be plain text ONLY:
  Example: (650) 721-2598
- DO NOT include (tel:) or any URI scheme
- DO NOT wrap phone numbers in brackets

TABLES:
- Tables are allowed ONLY using proper markdown table syntax
- NEVER place tables inside code blocks
- NEVER simulate tables using ASCII or pipes inside code blocks
- Keep tables simple (no bold, no inline formatting inside cells)

CODE BLOCKS:
- Use code blocks ONLY for real code examples (like Python or logs)
- NEVER use ```markdown or ``` for tables or formatting
- Logging examples must be plain markdown tables, NOT inside code blocks

LISTS:
- Use ONE list type per section
- Bullet list: "- item"
- Checklist: "- [ ] item"
- NEVER mix bullets and checklist syntax (no "• [ ]")

FORMATTING:
- Avoid special unicode characters (no non-breaking spaces, no fancy dashes)
- Use plain ASCII characters only
- Emojis allowed sparingly, NEVER in headings

GENERAL:
- Prefer simple structure over complex formatting
- Optimize for clean mobile rendering

{style_block}

Context chunks (indexed):
{indexed_context}

Task:
{instruction}

User topic:
{input_text}

{instructions_block}

Return JSON with this exact schema:
{schema}
""".strip()

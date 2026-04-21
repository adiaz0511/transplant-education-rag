import json
import re
import time

from app.config import (
    FALLBACK_MODEL,
    GROQ_TIMEOUT_SECONDS,
    PRIMARY_MODEL,
    QA_PRIMARY_MODEL,
    client,
)
from app.logging_utils import log_debug, log_info

CITATION_PATTERN = r"\[(\d+)\]"

TASK_MODELS = {
    "qa": {
        "required_keys": ["answer", "key_points", "source_indices", "sources"],
        "text_key": "answer",
    },
    "lesson": {
        "required_keys": ["title", "lesson_markdown", "key_takeaways", "source_indices", "sources"],
        "text_key": "lesson_markdown",
    },
    "quiz": {
        "required_keys": ["questions", "source_indices", "sources"],
        "text_key": None,
    },
}


def _repair_json_string_controls(raw_text: str) -> str:
    repaired = []
    in_string = False
    escaped = False

    for char in raw_text:
        if in_string:
            if escaped:
                repaired.append(char)
                escaped = False
                continue

            if char == "\\":
                repaired.append(char)
                escaped = True
            elif char == '"':
                repaired.append(char)
                in_string = False
            elif char == "\n":
                repaired.append("\\n")
            elif char == "\r":
                repaired.append("\\r")
            elif char == "\t":
                repaired.append("\\t")
            else:
                repaired.append(char)
        else:
            repaired.append(char)
            if char == '"':
                in_string = True

    return "".join(repaired)


def _extract_json_object(raw_text: str) -> str:
    start = raw_text.find("{")
    end = raw_text.rfind("}")
    if start == -1 or end == -1 or end < start:
        raise ValueError("No JSON object found in model response.")
    return raw_text[start:end + 1]


def _parse_model_json(raw_text: str) -> dict:
    log_debug("\n--- PARSE JSON START ---")
    candidate = _extract_json_object(raw_text.strip())
    log_debug("Extracted JSON candidate length:", len(candidate))

    try:
        parsed = json.loads(candidate)
        log_debug("JSON parsed without repair")
        log_debug("--- PARSE JSON END ---")
        return parsed
    except json.JSONDecodeError:
        log_debug("JSON parse failed, attempting repair")
        repaired = _repair_json_string_controls(candidate)
        parsed = json.loads(repaired)
        log_debug("JSON parsed after repair")
        log_debug("--- PARSE JSON END ---")
        return parsed


def _extract_citation_indices(text: str) -> list[int]:
    seen = []
    for match in re.findall(CITATION_PATTERN, text or ""):
        idx = int(match)
        if idx not in seen:
            seen.append(idx)
    return seen


def _text_blocks_for_citations(task: str, payload: dict) -> list[str]:
    if task == "lesson":
        text = payload.get("lesson_markdown", "")
        return [block.strip() for block in text.split("\n\n") if block.strip()]
    if task == "quiz":
        questions = payload.get("questions", [])
        return [
            item.get("explanation", "").strip()
            for item in questions
            if isinstance(item, dict) and item.get("explanation", "").strip()
        ]
    return []


def _select_supporting_sources(payload: dict, context_chunks: list[str]) -> tuple[list[int], list[str]]:
    citation_indices = []
    for key in ("answer", "lesson_markdown", "title"):
        value = payload.get(key)
        if isinstance(value, str):
            for idx in _extract_citation_indices(value):
                if 0 <= idx < len(context_chunks) and idx not in citation_indices:
                    citation_indices.append(idx)

    if isinstance(payload.get("questions"), list):
        for item in payload["questions"]:
            if not isinstance(item, dict):
                continue
            for field in ("question", "explanation"):
                value = item.get(field)
                if isinstance(value, str):
                    for idx in _extract_citation_indices(value):
                        if 0 <= idx < len(context_chunks) and idx not in citation_indices:
                            citation_indices.append(idx)

    if citation_indices:
        return citation_indices, [context_chunks[idx] for idx in citation_indices]

    text_parts = []
    for key in ("title", "answer", "lesson_markdown"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            text_parts.append(value.lower())

    if isinstance(payload.get("key_takeaways"), list):
        text_parts.extend(
            item.lower() for item in payload["key_takeaways"] if isinstance(item, str)
        )

    if isinstance(payload.get("key_points"), list):
        text_parts.extend(
            item.lower() for item in payload["key_points"] if isinstance(item, str)
        )

    combined_text = " ".join(text_parts)
    keyword_hits = []

    for idx, chunk in enumerate(context_chunks):
        chunk_words = {
            word.strip(".,:;()[]").lower()
            for word in chunk.split()
            if len(word.strip(".,:;()[]")) >= 5
        }
        overlap = sum(1 for word in chunk_words if word and word in combined_text)
        if overlap > 0:
            keyword_hits.append((idx, overlap))

    if keyword_hits:
        keyword_hits.sort(key=lambda item: item[1], reverse=True)
        selected_indices = [idx for idx, _score in keyword_hits[:2]]
    else:
        selected_indices = [0] if context_chunks else []

    return selected_indices, [context_chunks[idx] for idx in selected_indices]


def _normalize_payload(task: str, payload: dict, context_chunks: list[str]) -> dict:
    log_debug("\n--- NORMALIZE START ---")
    log_debug("Normalize task:", task)
    log_debug("Payload keys:", sorted(payload.keys()))
    model_info = TASK_MODELS[task]

    for key in model_info["required_keys"]:
        if key not in payload:
            raise ValueError(f"Missing required key: {key}")

    text_key = model_info["text_key"]
    if text_key:
        text_value = payload.get(text_key)
        if not isinstance(text_value, str) or not text_value.strip():
            raise ValueError(f"Missing or empty content field: {text_key}")

    for block in _text_blocks_for_citations(task, payload):
        if not _extract_citation_indices(block):
            raise ValueError(f"Missing citation markers in required {task} content.")

    if task == "quiz":
        for question in payload.get("questions", []):
            if not isinstance(question, dict):
                raise ValueError("Quiz questions must be objects.")
            explanation = question.get("explanation")
            if not isinstance(explanation, str) or not explanation.strip():
                raise ValueError("Each quiz question must include a non-empty explanation.")

    source_indices, sources = _select_supporting_sources(payload, context_chunks)
    if not source_indices or not sources:
        raise ValueError("Unable to determine supporting sources.")

    payload["source_indices"] = source_indices
    payload["sources"] = sources
    log_debug("Normalized source_indices:", source_indices)
    log_debug("Normalized sources count:", len(sources))
    log_debug("--- NORMALIZE END ---")
    return payload


def generate_json(prompt, task: str, context_chunks: list[str]):
    start = time.perf_counter()
    log_info("--- GENERATION START ---")
    log_info("Generation task:", task)
    log_info("Prompt length:", len(prompt))
    log_info("Context chunk count:", len(context_chunks))

    if task == "qa":
        model_candidates = [QA_PRIMARY_MODEL, FALLBACK_MODEL]
    else:
        model_candidates = [PRIMARY_MODEL, FALLBACK_MODEL]

    deduped_candidates = []
    for model_name in model_candidates:
        if model_name not in deduped_candidates:
            deduped_candidates.append(model_name)

    log_info("Model candidates:", deduped_candidates)

    for attempt_number, model_name in enumerate(deduped_candidates, start=1):
        try:
            attempt_start = time.perf_counter()
            log_info(f"--- MODEL ATTEMPT {attempt_number} START ---")
            log_info("Generation model:", model_name)
            log_info("Timeout seconds:", GROQ_TIMEOUT_SECONDS)
            response = client.chat.completions.create(
                model=model_name,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=1200,
                timeout=GROQ_TIMEOUT_SECONDS,
            )
            raw_content = response.choices[0].message.content or ""
            log_info("Response length:", len(raw_content))
            log_debug("Raw model response:")
            log_debug(raw_content)
            parsed = _parse_model_json(raw_content)
            log_info("Model JSON parse success")
            log_debug("Parsed model JSON:")
            log_debug(json.dumps(parsed, indent=2, ensure_ascii=False))
            normalized = _normalize_payload(task, parsed, context_chunks)
            log_info("Payload normalization success")
            log_debug("Normalized response JSON:")
            log_debug(json.dumps(normalized, indent=2, ensure_ascii=False))
            log_info("Model attempt elapsed:", round(time.perf_counter() - attempt_start, 3), "s")
            log_info("--- MODEL ATTEMPT SUCCESS ---")
            log_info("Total generation elapsed:", round(time.perf_counter() - start, 3), "s")
            log_info("--- GENERATION SUCCESS ---")
            return normalized
        except Exception as e:
            error_text = str(e)
            log_info(f"--- GENERATION ERROR ({model_name}) ---")
            log_info("Error type:", type(e).__name__)
            log_info(error_text)
            if model_name != deduped_candidates[-1]:
                log_info("Retrying with next model candidate.")
                continue
            log_info("Total generation elapsed before failure:", round(time.perf_counter() - start, 3), "s")
            raise

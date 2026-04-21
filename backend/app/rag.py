import re
import time
from collections import defaultdict
from functools import lru_cache

import numpy as np

from app.config import (
    HF_LOCAL_ONLY,
    PRELOAD_HYBRID_ON_STARTUP,
    PRELOAD_MEDCPT_ON_STARTUP,
    STRICT_HYBRID_RETRIEVAL,
    configure_torch_runtime,
    get_bm25_tokenized_chunks,
    get_chunks,
    get_hybrid_config,
    get_medcpt_index,
    get_medcpt_query_encoder,
    get_medcpt_tokenizer,
    get_specter_index,
    get_specter_query_encoder,
    get_specter_tokenizer,
)
from app.logging_utils import log_debug, log_info


def _tokenize_for_bm25(text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", (text or "").lower())


@lru_cache(maxsize=1)
def get_bm25_retriever():
    from rank_bm25 import BM25Okapi

    log_info("BM25 retriever build start")
    retriever = BM25Okapi(get_bm25_tokenized_chunks())
    log_info("BM25 retriever build complete")
    return retriever


def _encode_dense_query(query: str, tokenizer, model) -> np.ndarray:
    import faiss
    import torch

    configure_torch_runtime()
    encode_start = time.perf_counter()
    log_info("Dense query encode start")
    encoded = tokenizer(
        query,
        return_tensors="pt",
        truncation=True,
        max_length=512,
    )
    log_info("Dense query tokenization complete")

    with torch.inference_mode():
        outputs = model(**encoded)
        query_embedding = outputs.last_hidden_state[:, 0, :].cpu().numpy().astype("float32")
    log_info("Dense query forward pass complete")

    faiss.normalize_L2(query_embedding)
    log_info("Dense query normalization complete in", round(time.perf_counter() - encode_start, 3), "s")
    return query_embedding


def bm25_search(query: str, top_k: int) -> list[int]:
    search_start = time.perf_counter()
    log_info("BM25 search start; top_k:", top_k)
    retriever = get_bm25_retriever()
    tokens = _tokenize_for_bm25(query)
    scores = retriever.get_scores(tokens)
    ranked_indices = np.argsort(scores)[::-1]
    results = [int(idx) for idx in ranked_indices[:top_k]]
    log_info("BM25 search complete in", round(time.perf_counter() - search_start, 3), "s")
    log_info("BM25 top indices:", results)
    return results


def specter_search(query: str, top_k: int) -> list[int]:
    search_start = time.perf_counter()
    log_info("SPECTER search start; top_k:", top_k)
    index = get_specter_index()
    tokenizer = get_specter_tokenizer()
    model = get_specter_query_encoder()
    query_embedding = _encode_dense_query(query, tokenizer, model)
    log_info("SPECTER index search start")
    _scores, indices = index.search(query_embedding, top_k)
    results = [int(idx) for idx in indices[0] if idx >= 0]
    log_info("SPECTER search complete in", round(time.perf_counter() - search_start, 3), "s")
    log_info("SPECTER top indices:", results)
    return results


def medcpt_search(query: str, top_k: int) -> list[int]:
    search_start = time.perf_counter()
    log_info("MedCPT search start; top_k:", top_k)
    index = get_medcpt_index()
    tokenizer = get_medcpt_tokenizer()
    model = get_medcpt_query_encoder()
    query_embedding = _encode_dense_query(query, tokenizer, model)
    log_info("MedCPT index search start")
    _scores, indices = index.search(query_embedding, top_k)
    results = [int(idx) for idx in indices[0] if idx >= 0]
    log_info("MedCPT search complete in", round(time.perf_counter() - search_start, 3), "s")
    log_info("MedCPT top indices:", results)
    return results


def _reciprocal_rank_fusion(rankings: dict[str, list[int]], rrf_k: int) -> list[int]:
    fused_scores: dict[int, float] = defaultdict(float)

    for ranked_indices in rankings.values():
        for rank, chunk_idx in enumerate(ranked_indices, start=1):
            fused_scores[chunk_idx] += 1.0 / (rrf_k + rank)

    return [
        chunk_idx
        for chunk_idx, _score in sorted(
            fused_scores.items(),
            key=lambda item: item[1],
            reverse=True,
        )
    ]


def hybrid_retrieve(query: str, top_k: int | None = None) -> list[str]:
    start = time.perf_counter()
    config = get_hybrid_config()
    retriever_names = config["selected_retrievers"]
    top_k_per_retriever = config["top_k_per_retriever"]
    final_top_k = top_k if top_k is not None else config["max_context_chunks"]
    rrf_k = config["rrf_k"]

    log_info("--- HYBRID RETRIEVE START ---")
    log_info("Hybrid query:", query)
    log_info("Hybrid query length:", len(query))
    log_info("Selected retrievers:", retriever_names)
    log_info("Top k per retriever:", top_k_per_retriever)
    log_info("Final top k:", final_top_k)

    rankings: dict[str, list[int]] = {}

    for retriever_name in retriever_names:
        retriever_start = time.perf_counter()
        try:
            if retriever_name == "bm25":
                rankings["bm25"] = bm25_search(query, top_k_per_retriever)
            elif retriever_name == "specter":
                rankings["specter"] = specter_search(query, top_k_per_retriever)
            elif retriever_name == "medcpt":
                rankings["medcpt"] = medcpt_search(query, top_k_per_retriever)
            else:
                raise ValueError(f"Unsupported retriever in config: {retriever_name}")

            log_info(f"{retriever_name} ranked indices:", rankings[retriever_name])
            log_info(
                f"{retriever_name} elapsed:",
                round(time.perf_counter() - retriever_start, 3),
                "s",
            )
        except Exception as exc:
            log_info(f"{retriever_name} retrieval failed")
            log_info(f"{retriever_name} error type:", type(exc).__name__)
            log_info(f"{retriever_name} error:", str(exc))
            if STRICT_HYBRID_RETRIEVAL:
                raise RuntimeError(f"Configured retriever failed: {retriever_name}") from exc

    if not rankings:
        raise RuntimeError("All retrievers failed; no context available.")

    fused_indices = _reciprocal_rank_fusion(rankings, rrf_k)[:final_top_k]
    log_info("Fused indices:", fused_indices)

    chunks = get_chunks()
    results = [chunks[idx] for idx in fused_indices]
    log_info("Hybrid retrieve result count:", len(results))
    for idx, chunk in enumerate(results):
        log_info(f"Hybrid result[{idx}] preview:", chunk[:200].replace("\n", " "))
    log_info("Hybrid retrieve elapsed:", round(time.perf_counter() - start, 3), "s")
    log_info("--- HYBRID RETRIEVE END ---")
    return results


def retrieve(query, top_k=None):
    log_info("RETRIEVE entry")
    return hybrid_retrieve(query, top_k=top_k)


def warm_hybrid_retrievers():
    if not PRELOAD_HYBRID_ON_STARTUP:
        log_info("Hybrid warmup skipped: PRELOAD_HYBRID_ON_STARTUP is disabled")
        return

    start = time.perf_counter()
    warmup_query = "warmup query for transplant retrieval"
    log_info("=== HYBRID WARMUP START ===")
    try:
        get_hybrid_config()
        get_chunks()
        get_bm25_retriever()

        config = get_hybrid_config()
        selected_retrievers = config["selected_retrievers"]
        top_k_per_retriever = config["top_k_per_retriever"]

        if "medcpt" in selected_retrievers and PRELOAD_MEDCPT_ON_STARTUP:
            log_info("Hybrid warmup: MedCPT")
            medcpt_search(warmup_query, min(1, top_k_per_retriever))
        elif "medcpt" in selected_retrievers:
            log_info(
                "Hybrid warmup: MedCPT skipped",
                f"(PRELOAD_MEDCPT_ON_STARTUP={PRELOAD_MEDCPT_ON_STARTUP}, HF_LOCAL_ONLY={HF_LOCAL_ONLY})",
            )

        if "specter" in selected_retrievers:
            log_info("Hybrid warmup: SPECTER")
            specter_search(warmup_query, min(1, top_k_per_retriever))

        log_info("=== HYBRID WARMUP SUCCESS ===")
    except Exception as exc:
        log_info("=== HYBRID WARMUP ERROR ===")
        log_info("Warmup error type:", type(exc).__name__)
        log_info("Warmup error:", str(exc))
        if STRICT_HYBRID_RETRIEVAL:
            raise
    finally:
        log_info("Hybrid warmup elapsed:", round(time.perf_counter() - start, 3), "s")


def extract_retrieval_query(query: str) -> str:
    text = (query or "").strip()

    current_question_match = re.search(
        r"Current question:\s*(.+?)(?:\n\s*\n|Recent conversation:|$)",
        text,
        re.IGNORECASE | re.DOTALL,
    )
    if current_question_match:
        extracted = current_question_match.group(1).strip()
        if extracted:
            return " ".join(extracted.split())

    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if lines:
        return " ".join(lines[:2])[:300].strip()

    return text[:300].strip()

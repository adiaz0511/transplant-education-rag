from app.config import (
    STRICT_HYBRID_RETRIEVAL,
    get_bm25_tokenized_chunks,
    get_chunks,
    get_hybrid_config,
    get_medcpt_index,
    get_specter_index,
)
from app.rag import retrieve


print("System loaded")
print(f"Chunks: {len(get_chunks())}")
print(f"BM25 tokenized chunks: {len(get_bm25_tokenized_chunks())}")
print(f"SPECTER index size: {get_specter_index().ntotal}")
print(f"MedCPT index size: {get_medcpt_index().ntotal}")
print(f"Hybrid config: {get_hybrid_config()}")

config = get_hybrid_config()
assert config["selected_retrievers"] == ["bm25", "specter", "medcpt"], "Unexpected retriever order"
assert STRICT_HYBRID_RETRIEVAL is True, "Strict hybrid retrieval should be enabled for validation"
assert get_specter_index().ntotal == len(get_chunks()), "SPECTER index size must match chunks"
assert get_medcpt_index().ntotal == len(get_chunks()), "MedCPT index size must match chunks"

query = "What temperature is considered dangerous after transplant?"

print("\nQuery:", query)

results = retrieve(query, top_k=5)
assert len(results) == 5, "Expected five retrieved chunks"
assert any("101.4" in chunk or "100.4" in chunk for chunk in results), "Temperature guidance not found in retrieval results"

for i, result in enumerate(results, start=1):
    print("\n" + "=" * 60)
    print(f"Result {i}")
    print(result[:400])

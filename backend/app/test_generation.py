from app.generation import generate_json
from app.prompting import build_prompt
from app.rag import retrieve


query = "What temperature is considered dangerous after transplant?"

print("\nQuery:", query)

context_chunks = retrieve(query, top_k=5)
assert len(context_chunks) == 5, "Expected five retrieved chunks for generation"
assert any("101.4" in chunk or "100.4" in chunk for chunk in context_chunks), "Generation context missing temperature guidance"

print("\nRetrieved Chunks:")
for i, chunk in enumerate(context_chunks, start=1):
    print("\n" + "=" * 60)
    print(f"Chunk {i}")
    print(chunk[:300])

prompt = build_prompt(query, context_chunks, "qa")

print("\nGenerating answer...\n")

answer = generate_json(prompt, "qa", context_chunks)
assert isinstance(answer, dict), "Generation result should be a JSON object"
assert "source_indices" in answer, "Generation result must include source indices"
assert answer["source_indices"], "Generation result should cite at least one source"

print("Answer:\n")
print(answer)

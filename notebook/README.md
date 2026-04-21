# Notebook

This folder contains the notebook used to prepare the retrieval artifacts for the backend.

## Files

- `MedRAG_Retriever_Comparison_Backend_Export_4.ipynb`: Google Colab notebook for manual processing, retriever comparison, and backend artifact export.
- `Heart Transplant_Post-transplant Teaching Manual_English_Dec 2024.pdf`: source manual used as the project corpus.

## Notebook Purpose

The notebook performs the following steps:

1. Extracts text from the manual PDF.
2. Cleans and chunks the extracted text.
3. Builds retrieval artifacts for BM25, Contriever, SPECTER, and MedCPT.
4. Compares retrievers on representative transplant education questions.
5. Selects the final hybrid retrieval design.
6. Exports the backend package used by the FastAPI service.

## Relationship to the Backend

The backend uses the exported retrieval files from the notebook:

- `chunks.json`
- `bm25_index.json`
- `hybrid_retriever_config.json`
- `specter_faiss.index`
- `medcpt_faiss.index`

The backend copy of these files is located in `backend/data/`.

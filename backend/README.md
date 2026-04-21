# RAG Backend

A small FastAPI backend for the transplant education iOS app.

It provides three endpoints:

- `POST /ask`
- `POST /lesson`
- `POST /quiz`

The server uses:

- `BM25` for lexical retrieval
- `SPECTER` for dense scientific retrieval
- `MedCPT` for dense biomedical retrieval
- reciprocal rank fusion to merge retriever results
- `Groq` for response generation

This project was built for a master's class project and is intended to be simple to run for review and grading.

## Recommended Runtime

The primary supported runtime for this project is a local backend instance.

That is the intended full-capability setup for the app because the backend uses transformer-based retrieval plus FAISS. This works well locally, but can be memory-heavy on free hosting tiers.

A Render deployment configuration is included in the repo, but it should be treated as an optional deployment path rather than the main expected runtime for grading or demos.

## What This Backend Does

Given a user query or topic, the server:

1. runs BM25, SPECTER, and MedCPT retrieval
2. fuses those rankings with reciprocal rank fusion
3. selects the highest-ranked context chunks
4. builds a structured prompt
5. sends the prompt to Groq
6. returns JSON for the iOS app

The `/lesson` and `/quiz` responses include source references tied back to the retrieved chunks.

## Hybrid Retrieval Architecture

The backend now uses three retrievers:

1. `BM25`
2. `SPECTER`
3. `MedCPT`

The dense retrievers load query encoders at runtime:

- `allenai/specter`
- `ncbi/MedCPT-Query-Encoder`

The rankings are merged with reciprocal rank fusion using values from `data/hybrid_retriever_config.json`.

This replaces the older single-retriever MPNet setup.

## Required Data Files

These files must exist in `data/`:

- `chunks.json`
- `bm25_index.json`
- `hybrid_retriever_config.json`
- `specter_faiss.index`
- `medcpt_faiss.index`

The old MPNet artifacts are no longer used by the retrieval pipeline:

- `mpnet_faiss.index`
- `mpnet_embeddings.npy`
- `all-mpnet-base-v2`

## Project Structure

Important files:

- [app/main.py](app/main.py): FastAPI app and routes
- [app/security.py](app/security.py): request signing and lightweight auth
- [app/rag.py](app/rag.py): retrieval logic
- [app/config.py](app/config.py): hybrid retriever config and cached loaders
- [app/prompting.py](app/prompting.py): prompt construction
- [app/generation.py](app/generation.py): model response parsing and normalization
- [data/chunks.json](data/chunks.json): knowledge chunks
- [data/bm25_index.json](data/bm25_index.json): tokenized chunks for BM25
- [data/hybrid_retriever_config.json](data/hybrid_retriever_config.json): retriever and fusion settings
- [data/specter_faiss.index](data/specter_faiss.index): SPECTER vector index
- [data/medcpt_faiss.index](data/medcpt_faiss.index): MedCPT vector index
- [SECURITY_SETUP.md](SECURITY_SETUP.md): request signing details
- [render.yaml](render.yaml): Render deployment config

## Requirements

You need:

- Python 3.11
- `pip`
- a Groq API key

## Local Setup

From the project folder:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Create a local `.env` file. You can copy from `.env.example` and then replace the placeholder values:

```bash
cp .env.example .env
```

## Minimal `.env` for Local Development

Example:

```env
GROQ_API_KEY="YOUR_GROQ_API_KEY"

APP_ENV="development"
APP_DEBUG_LOGS="true"

APP_SHARED_SECRET="REPLACE_WITH_A_LONG_RANDOM_SECRET"
APP_ID="mx.devlabs.transplantguide"
ALLOWED_HOSTS="localhost,127.0.0.1"

SIGNATURE_MAX_AGE_SECONDS="300"
NONCE_TTL_SECONDS="300"

RATE_LIMIT_WINDOW_SECONDS="60"
RATE_LIMIT_MAX_REQUESTS_PER_IP="30"
RATE_LIMIT_MAX_REQUESTS_PER_APP="120"

GROQ_PRIMARY_MODEL="groq/compound"
GROQ_FALLBACK_MODEL="llama-3.3-70b-versatile"
GROQ_QA_PRIMARY_MODEL="llama-3.3-70b-versatile"
GROQ_TIMEOUT_SECONDS="20"
MAX_INSTRUCTIONS_CHARS="2000"

PRODUCTION_DOCS_ENABLED="false"
```

Notes:

- `GROQ_API_KEY` must be a valid Groq key
- `APP_ID` must match the iOS app
- `APP_SHARED_SECRET` must match the iOS app's signing secret
- for local testing, `ALLOWED_HOSTS` should include `localhost` and `127.0.0.1`

## Run the Server Locally

Recommended one-command launcher:

```bash
./scripts/run_local.sh
```

What it does:

- loads environment variables from `.env` if present
- uses local model folders only when both `local_models/specter` and `local_models/MedCPT-Query-Encoder` exist
- otherwise allows Hugging Face model loading at startup
- starts the backend with `STRICT_HYBRID_RETRIEVAL=true` so configured retriever failures are surfaced immediately

Manual alternative:

```bash
source venv/bin/activate
uvicorn app.main:app --reload
```

The server will run at:

```text
http://127.0.0.1:8000
```

## API Endpoints

### `POST /ask`

Request:

```json
{
  "query": "What symptoms mean I should call the transplant team?"
}
```

### `POST /lesson`

Request:

```json
{
  "topic": "0 to 2 Months After Transplant",
  "instructions": "optional formatting instructions"
}
```

### `POST /quiz`

Request:

```json
{
  "topic": "0 to 2 Months After Transplant",
  "instructions": "optional formatting instructions"
}
```

## Security / Request Signing

This backend now expects the iOS app to sign requests to:

- `/ask`
- `/lesson`
- `/quiz`

Required headers:

- `X-App-Id`
- `X-App-Version`
- `X-Timestamp`
- `X-Nonce`
- `X-Signature`

The signing format is documented in:

- [SECURITY_SETUP.md](SECURITY_SETUP.md)

Important:

- the shared secret is not committed to git
- local requests will fail if the app and server secrets do not match
- in production, the server fails closed if security config is missing

## Deployment

This repo includes a Render config:

- [render.yaml](render.yaml)

Important:

- local execution is the recommended way to run the full backend
- the Render setup is included as an optional deployment example
- free Render instances may not have enough memory for the full semantic retrieval stack used by this backend

To deploy on Render:

1. Create a new Web Service from this GitHub repo.
2. Let Render read `render.yaml`.
3. Add these environment variables in Render:
   - `GROQ_API_KEY`
   - `APP_SHARED_SECRET`
   - `APP_ID`
   - `ALLOWED_HOSTS`
4. Set `ALLOWED_HOSTS` to your Render hostname, for example:
   - `my-service.onrender.com`

If the Render service exceeds memory limits, continue using the local backend as the primary runtime for the app.

## Troubleshooting

### 401 Unauthorized

Usually means one of these:

- app ID does not match server `APP_ID`
- shared secret does not match
- timestamp is too old
- nonce was reused
- request body bytes changed after signing

### 429 Too Many Requests

The lightweight rate limit was hit. Wait a bit and try again.

### Groq errors

Check:

- `GROQ_API_KEY`
- internet access from the host
- model configuration in `.env`

### Embedding or startup issues

Make sure:

- dependencies were installed in the virtualenv
- the `data/` files are present
- Python version is compatible

## For Graders / Reviewers

To understand the project quickly:

1. read this file
2. check [app/main.py](app/main.py) for the API endpoints
3. check [SECURITY_SETUP.md](SECURITY_SETUP.md) for the request-signing setup

The `.env` file is intentionally not committed because it contains secrets.

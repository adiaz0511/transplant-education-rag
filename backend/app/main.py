import time
import uuid

from fastapi import Depends, FastAPI, Request
from fastapi.responses import JSONResponse
from starlette.middleware.trustedhost import TrustedHostMiddleware

from app.config import ALLOWED_HOSTS, APP_ENV, PRODUCTION_DOCS_ENABLED
from app.generation import generate_json
from app.logging_utils import log_debug, log_info, reset_request_id, set_request_id
from app.prompting import build_prompt
from app.rag import extract_retrieval_query, retrieve, warm_hybrid_retrievers
from app.schemas import QueryRequest, TopicRequest
from app.security import require_security_config, verify_app_request

docs_enabled = APP_ENV != "production" or PRODUCTION_DOCS_ENABLED
app = FastAPI(
    docs_url="/docs" if docs_enabled else None,
    redoc_url="/redoc" if docs_enabled else None,
    openapi_url="/openapi.json" if docs_enabled else None,
)
app.add_middleware(TrustedHostMiddleware, allowed_hosts=ALLOWED_HOSTS or ["*"])


@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    request_id = uuid.uuid4().hex[:8]
    request.state.request_id = request_id
    token = set_request_id(request_id)
    start = time.perf_counter()
    client_host = request.client.host if request.client else "unknown"
    log_info("HTTP request start:", request.method, request.url.path, "from", client_host)
    try:
        response = await call_next(request)
        log_info(
            "HTTP request complete:",
            request.method,
            request.url.path,
            "status",
            response.status_code,
            "elapsed",
            round(time.perf_counter() - start, 3),
            "s",
        )
        return response
    except Exception as exc:
        log_info(
            "HTTP request exception:",
            request.method,
            request.url.path,
            type(exc).__name__,
            str(exc),
            "elapsed",
            round(time.perf_counter() - start, 3),
            "s",
        )
        raise
    finally:
        reset_request_id(token)


@app.get("/")
async def healthcheck():
    return {"status": "ok"}


@app.on_event("startup")
async def startup_warmup():
    log_info("Application startup warmup begin")
    warm_hybrid_retrievers()
    log_info("Application startup warmup end")


@app.post("/ask")
async def ask(
    req: QueryRequest,
    request: Request,
    _auth: None = Depends(verify_app_request),
):
    request_start = time.perf_counter()
    log_info("=== /ask REQUEST START ===")
    log_info("App ID:", getattr(request.state, "app_id", "dev-bypass"))
    log_info("App Version:", getattr(request.state, "app_version", "dev-bypass"))
    log_info("Query length:", len(req.query))
    log_debug("Raw query:", req.query)

    try:
        retrieval_query = extract_retrieval_query(req.query)
        log_info("ASK retrieval query:", retrieval_query)
        log_info("ASK retrieval query length:", len(retrieval_query))

        log_info("ASK step 1: retrieve context")
        context = retrieve(retrieval_query)
        log_info("ASK retrieved chunks:", len(context))
        for idx, chunk in enumerate(context):
            log_info(f"ASK context[{idx}] length:", len(chunk))
            log_info(f"ASK context[{idx}] preview:", chunk[:300].replace("\n", " "))

        log_info("ASK step 2: build prompt")
        prompt = build_prompt(req.query, context, "qa")
        log_info("Prompt ready")
        log_info("Prompt length:", len(prompt))
        log_debug("ASK prompt preview:")
        log_debug(prompt[:3000])

        log_info("ASK step 3: generate JSON")
        payload = generate_json(prompt, "qa", context)
        log_info("ASK response keys:", sorted(payload.keys()))
        log_info("ASK total elapsed:", round(time.perf_counter() - request_start, 3), "s")
        log_info("=== /ask REQUEST END ===")
        return JSONResponse(payload)
    except Exception as e:
        log_info("=== /ask REQUEST ERROR ===")
        log_info("Error type:", type(e).__name__)
        log_info("Error:", str(e))
        log_info("ASK total elapsed before failure:", round(time.perf_counter() - request_start, 3), "s")
        raise


@app.post("/lesson")
async def lesson(
    req: TopicRequest,
    request: Request,
    _auth: None = Depends(verify_app_request),
):
    request_start = time.perf_counter()
    log_info("=== /lesson REQUEST START ===")
    log_info("App ID:", getattr(request.state, "app_id", "dev-bypass"))
    log_info("Topic length:", len(req.topic))
    log_info("Instructions length:", len(req.instructions or ""))

    log_info("LESSON step 1: retrieve context")
    context = retrieve(req.topic)
    log_info("Retrieved chunks:", len(context))

    log_info("LESSON step 2: build prompt")
    prompt = build_prompt(req.topic, context, "lesson", req.instructions)
    log_info("Prompt ready")
    log_info("Prompt length:", len(prompt))

    log_info("LESSON step 3: generate JSON")
    payload = generate_json(prompt, "lesson", context)
    log_info("LESSON response keys:", sorted(payload.keys()))
    log_info("LESSON total elapsed:", round(time.perf_counter() - request_start, 3), "s")
    log_info("=== /lesson REQUEST END ===")
    return JSONResponse(payload)


@app.post("/quiz")
async def quiz(
    req: TopicRequest,
    request: Request,
    _auth: None = Depends(verify_app_request),
):
    request_start = time.perf_counter()
    log_info("=== /quiz REQUEST START ===")
    log_info("App ID:", getattr(request.state, "app_id", "dev-bypass"))
    log_info("Topic length:", len(req.topic))

    log_info("QUIZ step 1: retrieve context")
    context = retrieve(req.topic)
    log_info("Retrieved chunks:", len(context))

    log_info("QUIZ step 2: build prompt")
    prompt = build_prompt(req.topic, context, "quiz", req.instructions)
    log_info("Prompt ready")
    log_info("Prompt length:", len(prompt))

    log_info("QUIZ step 3: generate JSON")
    payload = generate_json(prompt, "quiz", context)
    log_info("QUIZ response keys:", sorted(payload.keys()))
    log_info("QUIZ total elapsed:", round(time.perf_counter() - request_start, 3), "s")
    log_info("=== /quiz REQUEST END ===")
    return JSONResponse(payload)


require_security_config()

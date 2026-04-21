import json
import os
from collections import defaultdict, deque
from functools import lru_cache

from dotenv import load_dotenv
from groq import Groq

from app.logging_utils import log_info

load_dotenv()
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
PRIMARY_MODEL = os.getenv("GROQ_PRIMARY_MODEL", "groq/compound")
FALLBACK_MODEL = os.getenv("GROQ_FALLBACK_MODEL", "llama-3.3-70b-versatile")
QA_PRIMARY_MODEL = os.getenv("GROQ_QA_PRIMARY_MODEL", FALLBACK_MODEL)
MAX_INSTRUCTIONS_CHARS = int(os.getenv("MAX_INSTRUCTIONS_CHARS", "2000"))
GROQ_TIMEOUT_SECONDS = float(os.getenv("GROQ_TIMEOUT_SECONDS", "20"))
APP_ENV = os.getenv("APP_ENV", "development").lower()
APP_DEBUG_LOGS = os.getenv("APP_DEBUG_LOGS", "false").lower() == "true"
PRELOAD_HYBRID_ON_STARTUP = os.getenv("PRELOAD_HYBRID_ON_STARTUP", "true").lower() == "true"
PRELOAD_MEDCPT_ON_STARTUP = os.getenv("PRELOAD_MEDCPT_ON_STARTUP", "true").lower() == "true"
HF_LOCAL_ONLY = os.getenv("HF_LOCAL_ONLY", "false").lower() == "true"
STRICT_HYBRID_RETRIEVAL = os.getenv("STRICT_HYBRID_RETRIEVAL", "true").lower() == "true"
APP_SHARED_SECRET = os.getenv("APP_SHARED_SECRET", "")
APP_ID = os.getenv("APP_ID", "")
SIGNATURE_MAX_AGE_SECONDS = int(os.getenv("SIGNATURE_MAX_AGE_SECONDS", "300"))
NONCE_TTL_SECONDS = int(os.getenv("NONCE_TTL_SECONDS", "300"))
RATE_LIMIT_WINDOW_SECONDS = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))
RATE_LIMIT_MAX_REQUESTS_PER_IP = int(os.getenv("RATE_LIMIT_MAX_REQUESTS_PER_IP", "30"))
RATE_LIMIT_MAX_REQUESTS_PER_APP = int(os.getenv("RATE_LIMIT_MAX_REQUESTS_PER_APP", "120"))
ALLOWED_HOSTS = [
    host.strip() for host in os.getenv("ALLOWED_HOSTS", "*").split(",") if host.strip()
]
PRODUCTION_DOCS_ENABLED = os.getenv("PRODUCTION_DOCS_ENABLED", "false").lower() == "true"

BASE_PATH = os.path.dirname(os.path.dirname(__file__))
DATA_PATH = os.path.join(BASE_PATH, "data")
LOCAL_MODELS_PATH = os.path.join(BASE_PATH, "local_models")
LOCAL_SPECTER_MODEL_PATH = os.path.join(LOCAL_MODELS_PATH, "specter")
LOCAL_MEDCPT_MODEL_PATH = os.path.join(LOCAL_MODELS_PATH, "MedCPT-Query-Encoder")
CHUNKS_PATH = os.path.join(DATA_PATH, "chunks.json")
BM25_INDEX_PATH = os.path.join(DATA_PATH, "bm25_index.json")
HYBRID_CONFIG_PATH = os.path.join(DATA_PATH, "hybrid_retriever_config.json")
SPECTER_INDEX_PATH = os.path.join(DATA_PATH, "specter_faiss.index")
MEDCPT_INDEX_PATH = os.path.join(DATA_PATH, "medcpt_faiss.index")

client = Groq(api_key=GROQ_API_KEY, timeout=GROQ_TIMEOUT_SECONDS)
nonce_cache: dict[str, float] = {}
rate_limit_cache: dict[str, deque[float]] = defaultdict(deque)


@lru_cache(maxsize=1)
def get_chunks():
    log_info("CONFIG load chunks start:", CHUNKS_PATH)
    with open(CHUNKS_PATH, "r", encoding="utf-8") as f:
        chunks = json.load(f)
    log_info("CONFIG load chunks complete:", len(chunks), "chunks")
    return chunks


@lru_cache(maxsize=1)
def configure_torch_runtime():
    import torch

    log_info("CONFIG torch runtime setup start")
    torch.set_num_threads(1)
    try:
        torch.set_num_interop_threads(1)
    except RuntimeError:
        pass
    log_info(
        "CONFIG torch runtime setup complete; threads:",
        torch.get_num_threads(),
    )
    return True


@lru_cache(maxsize=1)
def get_bm25_index_payload():
    log_info("CONFIG load BM25 payload start:", BM25_INDEX_PATH)
    with open(BM25_INDEX_PATH, "r", encoding="utf-8") as f:
        payload = json.load(f)
    log_info("CONFIG load BM25 payload complete")
    return payload


@lru_cache(maxsize=1)
def get_bm25_tokenized_chunks():
    log_info("CONFIG build BM25 tokenized chunks start")
    tokenized_chunks = get_bm25_index_payload()["tokenized_chunks"]
    log_info("CONFIG build BM25 tokenized chunks complete:", len(tokenized_chunks), "documents")
    return tokenized_chunks


@lru_cache(maxsize=1)
def get_hybrid_config():
    log_info("CONFIG load hybrid config start:", HYBRID_CONFIG_PATH)
    with open(HYBRID_CONFIG_PATH, "r", encoding="utf-8") as f:
        config = json.load(f)
    log_info("CONFIG load hybrid config complete")
    return config


@lru_cache(maxsize=1)
def get_medcpt_model_source():
    configured_model_name = get_hybrid_config()["dense_retrievers"]["medcpt"]["query_model_name"]
    if os.path.isdir(LOCAL_MEDCPT_MODEL_PATH):
        log_info("CONFIG MedCPT model source: local path", LOCAL_MEDCPT_MODEL_PATH)
        return LOCAL_MEDCPT_MODEL_PATH
    log_info("CONFIG MedCPT model source: remote id", configured_model_name)
    return configured_model_name


@lru_cache(maxsize=1)
def get_specter_model_source():
    configured_model_name = get_hybrid_config()["dense_retrievers"]["specter"]["model_name"]
    if os.path.isdir(LOCAL_SPECTER_MODEL_PATH):
        log_info("CONFIG SPECTER model source: local path", LOCAL_SPECTER_MODEL_PATH)
        return LOCAL_SPECTER_MODEL_PATH
    log_info("CONFIG SPECTER model source: remote id", configured_model_name)
    return configured_model_name


@lru_cache(maxsize=1)
def get_specter_index():
    import faiss

    log_info("CONFIG load SPECTER FAISS start:", SPECTER_INDEX_PATH)
    index = faiss.read_index(SPECTER_INDEX_PATH)
    log_info("CONFIG load SPECTER FAISS complete")
    return index


@lru_cache(maxsize=1)
def get_medcpt_index():
    import faiss

    log_info("CONFIG load MedCPT FAISS start:", MEDCPT_INDEX_PATH)
    index = faiss.read_index(MEDCPT_INDEX_PATH)
    log_info("CONFIG load MedCPT FAISS complete")
    return index


@lru_cache(maxsize=1)
def get_specter_tokenizer():
    from transformers import AutoTokenizer

    model_source = get_specter_model_source()
    log_info("CONFIG load SPECTER tokenizer start:", model_source)
    tokenizer = AutoTokenizer.from_pretrained(model_source, local_files_only=HF_LOCAL_ONLY)
    log_info("CONFIG load SPECTER tokenizer complete")
    return tokenizer


@lru_cache(maxsize=1)
def get_specter_query_encoder():
    from transformers import AutoModel

    configure_torch_runtime()
    model_source = get_specter_model_source()
    log_info("CONFIG load SPECTER encoder start:", model_source)
    model = AutoModel.from_pretrained(model_source, local_files_only=HF_LOCAL_ONLY)
    model.eval()
    log_info("CONFIG load SPECTER encoder complete")
    return model


@lru_cache(maxsize=1)
def get_medcpt_tokenizer():
    from transformers import AutoTokenizer

    model_source = get_medcpt_model_source()
    log_info("CONFIG load MedCPT tokenizer start:", model_source)
    tokenizer = AutoTokenizer.from_pretrained(model_source, local_files_only=HF_LOCAL_ONLY)
    log_info("CONFIG load MedCPT tokenizer complete")
    return tokenizer


@lru_cache(maxsize=1)
def get_medcpt_query_encoder():
    from transformers import AutoModel

    configure_torch_runtime()
    model_source = get_medcpt_model_source()
    log_info("CONFIG load MedCPT encoder start:", model_source)
    model = AutoModel.from_pretrained(model_source, local_files_only=HF_LOCAL_ONLY)
    model.eval()
    log_info("CONFIG load MedCPT encoder complete")
    return model

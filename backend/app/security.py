import hashlib
import hmac
import time

from fastapi import HTTPException, Request, status

from app.config import (
    APP_ENV,
    APP_ID,
    APP_SHARED_SECRET,
    GROQ_API_KEY,
    NONCE_TTL_SECONDS,
    RATE_LIMIT_MAX_REQUESTS_PER_APP,
    RATE_LIMIT_MAX_REQUESTS_PER_IP,
    RATE_LIMIT_WINDOW_SECONDS,
    SIGNATURE_MAX_AGE_SECONDS,
    nonce_cache,
    rate_limit_cache,
)
from app.logging_utils import log_debug, log_info


def is_production() -> bool:
    return APP_ENV == "production"


def require_security_config():
    if not GROQ_API_KEY:
        raise RuntimeError("GROQ_API_KEY is required.")
    if is_production():
        missing = []
        if not APP_SHARED_SECRET:
            missing.append("APP_SHARED_SECRET")
        if not APP_ID:
            missing.append("APP_ID")
        if missing:
            raise RuntimeError(f"Missing required production security config: {', '.join(missing)}")


def _purge_nonces(now: float):
    expired = [nonce for nonce, expires_at in nonce_cache.items() if expires_at <= now]
    for nonce in expired:
        nonce_cache.pop(nonce, None)


def _enforce_rate_limit(bucket: str, limit: int):
    now = time.time()
    window_start = now - RATE_LIMIT_WINDOW_SECONDS
    timestamps = rate_limit_cache[bucket]

    while timestamps and timestamps[0] <= window_start:
        timestamps.popleft()

    if len(timestamps) >= limit:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded.",
        )

    timestamps.append(now)


def _constant_time_compare(left: str, right: str) -> bool:
    return hmac.compare_digest(left.encode("utf-8"), right.encode("utf-8"))


def _build_signature(
    method: str,
    path: str,
    timestamp: str,
    nonce: str,
    body: bytes,
) -> str:
    message = b"\n".join(
        [
            method.upper().encode("utf-8"),
            path.encode("utf-8"),
            timestamp.encode("utf-8"),
            nonce.encode("utf-8"),
            body,
        ]
    )
    return hmac.new(
        APP_SHARED_SECRET.encode("utf-8"),
        message,
        hashlib.sha256,
    ).hexdigest()


async def verify_app_request(request: Request):
    log_info("\n--- APP AUTH START ---")

    if not APP_SHARED_SECRET or not APP_ID:
        log_info("Auth mode: bypass (missing APP_SHARED_SECRET or APP_ID)")
        if is_production():
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Server security configuration is incomplete.",
            )
        return

    headers = request.headers
    app_id = headers.get("X-App-Id", "")
    app_version = headers.get("X-App-Version", "")
    timestamp = headers.get("X-Timestamp", "")
    nonce = headers.get("X-Nonce", "")
    signature = headers.get("X-Signature", "")

    log_info("Request path:", request.url.path)
    log_info("Received app id:", app_id)
    log_info("Configured app id:", APP_ID)
    log_info("Received app version:", app_version or "<missing>")
    log_info("Received timestamp:", timestamp or "<missing>")
    log_info("Received nonce prefix:", nonce[:12] if nonce else "<missing>")
    log_info("Received signature prefix:", signature[:16] if signature else "<missing>")
    log_debug("Header presence:", {
        "X-App-Id": bool(app_id),
        "X-App-Version": bool(app_version),
        "X-Timestamp": bool(timestamp),
        "X-Nonce": bool(nonce),
        "X-Signature": bool(signature),
    })

    if not all([app_id, app_version, timestamp, nonce, signature]):
        log_info("Auth failure: missing required headers")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing required app authentication headers.",
        )

    if app_id != APP_ID:
        log_info("Auth failure: app id mismatch")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid app identity.",
        )

    try:
        timestamp_value = int(timestamp)
    except ValueError as exc:
        log_info("Auth failure: invalid timestamp format")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid request timestamp.",
        ) from exc

    now = int(time.time())
    log_info("Server now:", now)
    log_info("Timestamp delta seconds:", now - timestamp_value)
    if abs(now - timestamp_value) > SIGNATURE_MAX_AGE_SECONDS:
        log_info("Auth failure: timestamp outside allowed window")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Request timestamp is outside the allowed window.",
        )

    if len(nonce) < 16:
        log_info("Auth failure: nonce too short")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid nonce.",
        )

    _purge_nonces(time.time())
    if nonce in nonce_cache:
        log_info("Auth failure: replay detected")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Replay detected.",
        )

    body = await request.body()
    log_info("Request body length:", len(body))
    log_debug("Request body preview:", body[:500].decode("utf-8", errors="replace"))
    expected_signature = _build_signature(
        request.method,
        request.url.path,
        timestamp,
        nonce,
        body,
    )
    log_info("Expected signature prefix:", expected_signature[:16])

    if not _constant_time_compare(signature, expected_signature):
        log_info("Auth failure: signature mismatch")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid request signature.",
        )

    client_ip = request.client.host if request.client else "unknown"
    log_info("Client IP:", client_ip)
    _enforce_rate_limit(f"ip:{client_ip}", RATE_LIMIT_MAX_REQUESTS_PER_IP)
    _enforce_rate_limit(f"app:{app_id}", RATE_LIMIT_MAX_REQUESTS_PER_APP)
    nonce_cache[nonce] = time.time() + NONCE_TTL_SECONDS
    request.state.app_id = app_id
    request.state.app_version = app_version
    log_info("App auth success")
    log_info("--- APP AUTH END ---")

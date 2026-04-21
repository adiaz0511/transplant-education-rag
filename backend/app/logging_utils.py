import os
from contextvars import ContextVar
from datetime import datetime

_request_id: ContextVar[str] = ContextVar("request_id", default="-")
APP_DEBUG_LOGS = os.getenv("APP_DEBUG_LOGS", "false").lower() == "true"


def set_request_id(request_id: str):
    return _request_id.set(request_id)


def reset_request_id(token):
    _request_id.reset(token)


def get_request_id() -> str:
    return _request_id.get()


def _format_parts(level: str, parts: tuple) -> tuple:
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    prefix = f"[{timestamp}] [{level}] [req:{get_request_id()}]"
    return (prefix, *parts)


def log_info(*parts):
    print(*_format_parts("INFO", parts), flush=True)


def log_debug(*parts):
    if APP_DEBUG_LOGS:
        print(*_format_parts("DEBUG", parts), flush=True)

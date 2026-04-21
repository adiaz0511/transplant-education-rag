#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PYTHON="$ROOT_DIR/venv/bin/python"
ENV_FILE="$ROOT_DIR/.env"
LOCAL_SPECTER_DIR="$ROOT_DIR/local_models/specter"
LOCAL_MEDCPT_DIR="$ROOT_DIR/local_models/MedCPT-Query-Encoder"

if [[ ! -x "$VENV_PYTHON" ]]; then
  echo "Missing virtual environment Python at $VENV_PYTHON"
  echo "Run scripts/setup.sh first."
  exit 1
fi

cd "$ROOT_DIR"

if [[ -f "$ENV_FILE" ]]; then
  echo "Loading environment from .env..."
  set -a
  source "$ENV_FILE"
  set +a
fi

if [[ -d "$LOCAL_SPECTER_DIR" ]]; then
  echo "Using local SPECTER model files from $LOCAL_SPECTER_DIR"
else
  echo "No local SPECTER directory found at $LOCAL_SPECTER_DIR"
  echo "The server may try to fetch SPECTER from Hugging Face during startup."
fi

if [[ -d "$LOCAL_MEDCPT_DIR" ]]; then
  echo "Using local MedCPT model files from $LOCAL_MEDCPT_DIR"
else
  echo "No local MedCPT directory found at $LOCAL_MEDCPT_DIR"
  echo "The server may try to fetch MedCPT from Hugging Face during startup."
fi

echo "Starting FastAPI server..."
if [[ -d "$LOCAL_SPECTER_DIR" && -d "$LOCAL_MEDCPT_DIR" ]]; then
  export HF_LOCAL_ONLY=true
  echo "HF_LOCAL_ONLY=true"
else
  export HF_LOCAL_ONLY=false
  echo "HF_LOCAL_ONLY=false"
fi
export PRELOAD_MEDCPT_ON_STARTUP=true
export STRICT_HYBRID_RETRIEVAL=true
exec "$VENV_PYTHON" -m uvicorn app.main:app

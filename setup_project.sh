#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
IOS_DIR="$ROOT_DIR/ios"
BACKEND_ENV_FILE="$BACKEND_DIR/.env"
IOS_SECRETS_FILE="$IOS_DIR/TransplantGuide/Config/BackendSecrets.local.xcconfig"
DEFAULT_BACKEND_URL="http://127.0.0.1:8000"
DEFAULT_APP_ID="mx.devlabs.transplantguide"

if [[ ! -d "$BACKEND_DIR" || ! -d "$IOS_DIR" ]]; then
  echo "This script must be run from the repository's source folder."
  echo "Expected folders: backend/ and ios/"
  exit 1
fi

echo "Pediatric Heart Transplant Education RAG setup"
echo

if [[ -f "$BACKEND_ENV_FILE" || -f "$IOS_SECRETS_FILE" ]]; then
  echo "Existing local configuration was found."
  [[ -f "$BACKEND_ENV_FILE" ]] && echo "  backend/.env"
  [[ -f "$IOS_SECRETS_FILE" ]] && echo "  ios/TransplantGuide/Config/BackendSecrets.local.xcconfig"
  echo
  read -r -p "Overwrite local configuration? [y/N]: " OVERWRITE
  case "$OVERWRITE" in
    y|Y|yes|YES) ;;
    *)
      echo "Setup cancelled."
      exit 0
      ;;
  esac
  echo
fi

BACKEND_URL="$DEFAULT_BACKEND_URL"
APP_ID="$DEFAULT_APP_ID"

echo "Using backend URL: $BACKEND_URL"
echo "Using app ID: $APP_ID"
echo

read -r -p "Groq API key: " GROQ_API_KEY

if [[ -z "$GROQ_API_KEY" ]]; then
  echo "GROQ_API_KEY is required."
  exit 1
fi

if command -v openssl >/dev/null 2>&1; then
  APP_SHARED_SECRET="$(openssl rand -hex 32)"
else
  APP_SHARED_SECRET="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
fi

cat > "$BACKEND_ENV_FILE" <<EOF
GROQ_API_KEY="$GROQ_API_KEY"

APP_ENV="development"
APP_DEBUG_LOGS="false"

APP_SHARED_SECRET="$APP_SHARED_SECRET"
APP_ID="$APP_ID"
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
EOF

cat > "$IOS_SECRETS_FILE" <<EOF
BACKEND_BASE_URL = "$BACKEND_URL"
BACKEND_APP_ID = $APP_ID
BACKEND_SHARED_SECRET = $APP_SHARED_SECRET
EOF

echo
echo "Wrote backend configuration:"
echo "  backend/.env"
echo
echo "Wrote iOS local configuration:"
echo "  ios/TransplantGuide/Config/BackendSecrets.local.xcconfig"
echo

if [[ ! -x "$BACKEND_DIR/venv/bin/python" ]]; then
  echo "Backend virtual environment not found. Installing backend dependencies..."
  (cd "$BACKEND_DIR" && ./scripts/setup.sh)
else
  echo "Backend virtual environment already exists. Skipping dependency install."
fi

echo
if [[ ! -f "$BACKEND_DIR/local_models/MedCPT-Query-Encoder/model.safetensors" ]]; then
  echo "The MedCPT local model file was not found."
  echo "The first backend run can download it automatically, but that may look like a long pause."
  echo "Expected download size: about 418 MB."
  echo
  read -r -p "Download the local MedCPT model now? [y/N]: " DOWNLOAD_MODEL
  case "$DOWNLOAD_MODEL" in
    y|Y|yes|YES)
      "$ROOT_DIR/download_models.sh"
      ;;
    *)
      echo "Skipping model download. The backend may download it on first startup or first request."
      ;;
  esac
fi

echo
echo "Setup complete."
echo
echo "Next steps:"
echo "  ./run_backend.sh"
echo "  ./open_ios.sh"
echo
echo "If the iOS app was already installed or running, rebuild it in Xcode after setup."
echo "The setup script generates a new shared secret, and the app must be rebuilt to use it."

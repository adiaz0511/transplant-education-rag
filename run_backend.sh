#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"

if [[ ! -f "$BACKEND_DIR/.env" ]]; then
  echo "Missing backend/.env."
  echo "Run ./setup_project.sh first."
  exit 1
fi

if [[ ! -x "$BACKEND_DIR/venv/bin/python" ]]; then
  echo "Missing backend virtual environment."
  echo "Run ./setup_project.sh first."
  exit 1
fi

cd "$BACKEND_DIR"
exec ./scripts/run_local.sh

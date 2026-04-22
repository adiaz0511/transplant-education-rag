#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
VENV_PYTHON="$BACKEND_DIR/venv/bin/python"
MODEL_DIR="$BACKEND_DIR/local_models/MedCPT-Query-Encoder"
MODEL_ID="ncbi/MedCPT-Query-Encoder"

if [[ ! -x "$VENV_PYTHON" ]]; then
  echo "Missing backend virtual environment."
  echo "Run ./setup_project.sh first."
  exit 1
fi

mkdir -p "$MODEL_DIR"

echo "Downloading MedCPT query encoder model."
echo "This download is about 418 MB and only needs to happen once."
echo "Destination: backend/local_models/MedCPT-Query-Encoder"
echo

"$VENV_PYTHON" - <<PY
from pathlib import Path
from transformers import AutoModel, AutoTokenizer

model_id = "$MODEL_ID"
model_dir = Path("$MODEL_DIR")

print(f"Loading tokenizer from {model_id}...")
tokenizer = AutoTokenizer.from_pretrained(model_id)
print(f"Saving tokenizer to {model_dir}...")
tokenizer.save_pretrained(model_dir)

print(f"Loading model from {model_id}...")
model = AutoModel.from_pretrained(model_id)
print(f"Saving model to {model_dir}...")
model.save_pretrained(model_dir, safe_serialization=True)

print("Model download complete.")
PY

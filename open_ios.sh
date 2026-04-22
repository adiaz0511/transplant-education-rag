#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_PROJECT="$ROOT_DIR/ios/TransplantGuide.xcodeproj"
IOS_SECRETS_FILE="$ROOT_DIR/ios/TransplantGuide/Config/BackendSecrets.local.xcconfig"

if [[ ! -f "$IOS_SECRETS_FILE" ]]; then
  echo "Missing iOS local secrets file."
  echo "Run ./setup_project.sh first."
  exit 1
fi

open "$IOS_PROJECT"

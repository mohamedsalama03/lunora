#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_FILE="$PROJECT_ROOT/ios/Flutter/Secrets.xcconfig"

get_xcconfig_value() {
  local key="$1"
  if [[ ! -f "$SECRETS_FILE" ]]; then
    return 0
  fi

  grep -E "^[[:space:]]*$key[[:space:]]*=" "$SECRETS_FILE" \
    | tail -n 1 \
    | sed -E "s/^[[:space:]]*$key[[:space:]]*=[[:space:]]*//"
}

MAPS_API_KEY="${DART_MAPS_API_KEY:-}"
if [[ -z "${MAPS_API_KEY// }" ]]; then
  MAPS_API_KEY="${GOOGLE_MAPS_API_KEY:-}"
fi
if [[ -z "${MAPS_API_KEY// }" ]]; then
  MAPS_API_KEY="$(get_xcconfig_value "GOOGLE_MAPS_API_KEY")"
fi

if [[ -z "${MAPS_API_KEY// }" || "$MAPS_API_KEY" == "YOUR_IOS_GOOGLE_MAPS_KEY" ]]; then
  echo "Missing Google Maps API key."
  echo "Copy ios/Flutter/Secrets.xcconfig.example to ios/Flutter/Secrets.xcconfig and set GOOGLE_MAPS_API_KEY."
  exit 1
fi

cd "$PROJECT_ROOT"
flutter build ipa --release --dart-define="DART_MAPS_API_KEY=$MAPS_API_KEY"

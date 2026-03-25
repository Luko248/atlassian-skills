#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# confluence-get-page.sh — Get a Confluence page by ID
#
# Usage: confluence-get-page.sh <PAGE_ID> [EXPAND]
# Example: confluence-get-page.sh 12345
# Example: confluence-get-page.sh 12345 "body.storage,version,ancestors"
#
# EXPAND: optional comma-separated list of fields to expand
#         default: "body.storage,version,space"
# ──────────────────────────────────────────────────────────────
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load-env.sh"

PAGE_ID="${1:?Usage: confluence-get-page.sh <PAGE_ID> [EXPAND]}"
EXPAND="${2:-body.storage,version,space}"

if [[ -z "${CONFLUENCE_URL:-}" || -z "${CONFLUENCE_API_TOKEN:-}" ]]; then
  echo '{"error": "CONFLUENCE_URL and CONFLUENCE_API_TOKEN must be set in .env or environment"}' >&2
  exit 1
fi

CURL_OPTS=(-s -S --max-time 60 --connect-timeout 30)
if [[ "${VALIDATE_SSL:-true}" == "false" ]]; then
  CURL_OPTS+=(-k)
fi

ENCODED_EXPAND=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$EXPAND")

URL="${CONFLUENCE_URL}/rest/api/content/${PAGE_ID}?expand=${ENCODED_EXPAND}"

curl "${CURL_OPTS[@]}" \
  -H "Authorization: Bearer ${CONFLUENCE_API_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "$URL"

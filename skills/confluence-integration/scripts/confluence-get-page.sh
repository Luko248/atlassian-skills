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

# Validate page ID is numeric
if ! [[ "$PAGE_ID" =~ ^[0-9]+$ ]]; then
  echo '{"error": "PAGE_ID must be a numeric value"}' >&2
  exit 1
fi

# Validate expand parameter contains only safe characters
if [[ ! "$EXPAND" =~ ^[a-zA-Z0-9.,_-]+$ ]]; then
  echo '{"error": "EXPAND parameter contains invalid characters"}' >&2
  exit 1
fi

if [[ -z "${CONFLUENCE_URL:-}" || -z "${CONFLUENCE_API_TOKEN:-}" ]]; then
  echo '{"error": "CONFLUENCE_URL and CONFLUENCE_API_TOKEN must be set in .env or environment"}' >&2
  exit 1
fi

_validate_url "CONFLUENCE_URL" "$CONFLUENCE_URL"
_validate_token "CONFLUENCE_API_TOKEN" "$CONFLUENCE_API_TOKEN"
_build_curl_opts

ENCODED_EXPAND=$(printf '%s' "$EXPAND" | python3 -S -E -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))")

URL="${CONFLUENCE_URL}/rest/api/content/${PAGE_ID}?expand=${ENCODED_EXPAND}"

curl "${CURL_OPTS[@]}" \
  -H "Authorization: Bearer ${CONFLUENCE_API_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "$URL"

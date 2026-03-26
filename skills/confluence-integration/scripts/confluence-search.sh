#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# confluence-search.sh — Search Confluence pages using CQL
#
# Usage: confluence-search.sh <CQL_QUERY> [LIMIT]
# Example: confluence-search.sh "type=page AND text~'deployment'" 25
#
# LIMIT: 1-100, default 25
# ──────────────────────────────────────────────────────────────
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load-env.sh"

CQL="${1:?Usage: confluence-search.sh <CQL_QUERY> [LIMIT]}"
LIMIT="${2:-25}"

if [[ -z "${CONFLUENCE_URL:-}" || -z "${CONFLUENCE_API_TOKEN:-}" ]]; then
  echo '{"error": "CONFLUENCE_URL and CONFLUENCE_API_TOKEN must be set in .env or environment"}' >&2
  exit 1
fi

# Validate numeric parameter
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo '{"error": "LIMIT must be a positive integer"}' >&2
  exit 1
fi

# Clamp limit
if (( LIMIT < 1 )); then LIMIT=1; fi
if (( LIMIT > 100 )); then LIMIT=100; fi

_validate_url "CONFLUENCE_URL" "$CONFLUENCE_URL"
_validate_token "CONFLUENCE_API_TOKEN" "$CONFLUENCE_API_TOKEN"
_build_curl_opts

# URL-encode the CQL query safely via stdin
ENCODED_CQL=$(printf '%s' "$CQL" | python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))")

URL="${CONFLUENCE_URL}/rest/api/content/search?cql=${ENCODED_CQL}&limit=${LIMIT}"

curl "${CURL_OPTS[@]}" \
  -H "Authorization: Bearer ${CONFLUENCE_API_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "$URL"
